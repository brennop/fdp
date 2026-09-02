# frozen_string_literal: true

class GameState
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Turbo::Broadcastable

  attribute :game_id, :integer
  attribute :round, :integer, default: 0
  attribute :turn_player_index, :integer, default: 0
  attribute :dealer_index, :integer, default: 0
  attribute :lives, default: -> { {} }         # { player_id => lives_remaining }
  attribute :bids, default: -> { {} }          # { player_id => bid } for current round
  attribute :tricks_won, default: -> { {} }    # { player_id => count } for current round
  attribute :current_trick, default: -> { [] } # [[player_id, card], ...]
  attribute :last_trick, default: -> { [] }    # [[player_id, card], ...]
  attribute :hands, default: -> { {} }         # { player_id => [cards] }
  attribute :last_move_id, :integer # FIXME: might be removed
  attribute :hand_size, :integer, default: 1

  def self.for(move)
    return move.prev_state.apply(move) if move.id.nil?

    Rails.cache.fetch("game_state/#{move.id}") { compute(move) }
  end

  def self.compute(move)
    move.game.moves.order(:id).reduce(initial(move.game)) { |state, move| state.apply(move) }
  end

  def self.initial(game)
    new(
      lives: game.players.ids.index_with { game.starting_lives }
    ).deal_hands(game.seed)
  end

  def apply(move)
    raise Exceptions::IllegalMove, "It's #{current_player.name} turn to play" if move.player.id != turn_player_id

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

  def last_bidder?
    alive_players.size - bids.size == 1
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

  def winner
    Player.find_by(id: alive_players.first)
  end

  def hook
    hand_size - bids.values.sum
  end

  def legal_bids
    return (0..hand_size).to_a - [hook] if last_bidder?

    (0..hand_size)
  end

  # TODO: hook
  def apply_bid(move)
    raise Exceptions::IllegalMove, "Can't bid #{move.value}" unless legal_bids.map(&:to_s).include? move.value

    self.bids = bids.merge(move.player_id => move.value.to_i)
    self.turn_player_index = next_index(turn_player_index)
    self
  end

  def apply_card(move)
    raise Exceptions::IllegalMove, "Can't play card" unless hands[move.player.id].include? move.value

    self.current_trick = current_trick + [ [ move.player_id, move.value ] ]
    self.hands = hands.merge(move.player_id => hands[move.player_id] - [ move.value ])
    self.turn_player_index = next_index(turn_player_index)

    if current_trick.size == alive_players.size
      resolve_trick!
      advance_round!(move.game.seed) if round_over?
    end

    self
  end

  def resolve_trick!
    winner_id = sorted_trick.first.first
    self.tricks_won = tricks_won.merge(winner_id => tricks_won.fetch(winner_id, 0) + 1)
    self.last_trick = sorted_trick
    self.current_trick = []
    self.turn_player_index = alive_players.index(winner_id)
  end

  def advance_round!(seed)
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
    deal_hands(seed)
  end

  def deal_hands(seed)
    self.hands = alive_players.zip(Deck.deal(seed, round, hand_size)).to_h
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

  def display_trick
    sorted_trick.empty? ? last_trick : sorted_trick
  end
end
