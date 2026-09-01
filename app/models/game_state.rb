# frozen_string_literal: true

class GameState
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Turbo::Broadcastable

  attribute :game_id, :integer
  attribute :round, :integer, default: -1
  attribute :turn_player_index, :integer, default: -1
  attribute :dealer_index, :integer, default: -1
  attribute :lives, default: -> { {} }         # { player_id => lives_remaining }
  attribute :bids, default: -> { {} }          # { player_id => bid } for current round
  attribute :tricks_won, default: -> { {} }    # { player_id => count } for current round
  attribute :current_trick, default: -> { [] } # [[player_id, card], ...]
  attribute :hands, default: -> { {} }         # { player_id => [cards] }
  attribute :hook, :integer
  attribute :last_move_id, :integer
  attribute :hand_size, :integer, default: -1

  def self.for(game)
    Rails.cache.fetch(cache_key_for(game)) { compute(game) }
  end

  def self.compute(game)
    initial = new(
      game_id: game.id,
      lives: game.players.ids.index_with { game.starting_lives }
    )

    initial.advance_round!

    game.moves.order(:id).reduce(initial) { |state, move| state.apply(move) }
  end

  def game
    Game.find(game_id)
  end

  def apply(move)
    next_state = self.class.new(attributes.merge(last_move_id: move.id))

    if bidding_phase?
      next_state.apply_bid(move)
    else
      next_state.apply_card(move)
    end
  end

  def bidding_phase?
    bids.size < alive_players.size
  end

  def self.cache_key_for(game)
    last_id = game.moves.maximum(:id) || 0
    "game_state/#{game.seed}/#{last_id}"
  end

  def turn_player_id
    alive_players.to_a[turn_player_index]
  end

  def current_player
    Player.find(turn_player_id)
  end

  def game_over?
    alive_players.size <= 1
  end

  # TODO: hook
  def apply_bid(move)
    self.bids = bids.merge(move.player_id => move.value.to_i)
    self.turn_player_index = next_index(turn_player_index)
    self
  end

  def apply_card(move)
    self.current_trick = current_trick + [ [ move.player_id, move.value ] ]
    self.hands = hands.merge(move.player_id => hands[move.player_id] - [ move.value ])
    self.turn_player_index = next_index(turn_player_index)

    if current_trick.size == alive_players.size
      resolve_trick!
      advance_round! if round_over?
    end

    self
  end

  def resolve_trick!
    winner_id = sorted_trick.first.first
    self.tricks_won = tricks_won.merge(winner_id => tricks_won.fetch(winner_id, 0) + 1)
    self.current_trick = []
    self.turn_player_index = alive_players.index(winner_id)
  end

  def advance_round!
    self.lives = lives.merge(
      bids.to_h { |pid, bid| [ pid, lives[pid] - (tricks_won.fetch(pid, 0) - bid).abs ] }
    )

    self.round += 1
    self.bids = {}
    self.tricks_won = {}

    return self if alive_players.empty?

    self.dealer_index = next_index(dealer_index)
    self.turn_player_index = dealer_index
    self.hand_size = (self.hand_size + 1) % (Deck.size / alive_players.count)
    self.hand_size += 1 if self.hand_size == 0
    self.hands = alive_players.zip(Deck.deal(game.seed, round, hand_size)).to_h
    self
  end

  def next_index(index)
    (index + 1) % alive_players.count
  end

  def alive_players
    lives.select { |_, value| value.positive? }.keys
  end

  def round_over?
    tricks_won.values.sum == hand_size
  end

  def sorted_trick
    current_trick.sort_by { |_, card| -Deck.rank(card) }
  end
end
