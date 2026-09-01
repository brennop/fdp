# frozen_string_literal: true

# export type Phase =
#   | 'idle'
#   | 'bidding'
#   | 'playing'
#   | 'roundComplete'
#   | 'gameComplete';
class GameState
  include ActiveModel::Model
  include ActiveModel::Attributes

  RANK_ORDER = {
    # Manilhas
    # "4C" => 40, # Zap
    # "7H" => 39,
    # "AS" => 38,
    # "7D" => 37,

    # 3
    "3C" => 36,
    "3H" => 35,
    "3S" => 34,
    "3D" => 33,

    # 2
    "2C" => 32,
    "2H" => 31,
    "2S" => 30,
    "2D" => 29,

    # A
    "AC" => 28,
    "AH" => 27,
    "AS" => 38, # Espadilha
    "AD" => 26,

    # K
    "KC" => 25,
    "KH" => 24,
    "KS" => 23,
    "KD" => 22,

    # Q
    "QC" => 21,
    "QH" => 20,
    "QS" => 19,
    "QD" => 18,

    # J
    "JC" => 17,
    "JH" => 16,
    "JS" => 15,
    "JD" => 14,

    # 7
    "7C" => 13,
    "7H" => 39, # 7 de ouros
    "7S" => 12,
    "7D" => 37, # 7 de copas

    # 6
    "6C" => 11,
    "6H" => 10,
    "6S" => 9,
    "6D" => 8,

    # 5
    "5C" => 7,
    "5H" => 6,
    "5S" => 5,
    "5D" => 4,

    # 4
    "4C" => 40, # Zap
    "4H" => 3,
    "4S" => 2, # TODO: PORCAO
    "4D" => 1
  }.freeze

  attribute :game_id, :integer
  attribute :phase, :string
  attribute :turn_player_index, :integer, default: 0
  attribute :dealer_index, :integer, default: 0
  attribute :lives, default: -> { {} }         # { player_id => lives_remaining }
  attribute :bids, default: -> { {} }          # { player_id => bid } for current round
  attribute :tricks_won, default: -> { {} }    # { player_id => count } for current round
  attribute :current_trick, default: -> { [] } # [[player_id, card], ...]
  attribute :hook, :integer
  attribute :last_move_id, :integer
  attribute :hand_size, :integer

  def self.for(game)
    Rails.cache.fetch(cache_key_for(game)) { compute(game) }
  end

  def self.compute(game)
    initial = new(lives: game.players.index_with { game.starting_lives })

    game.moves.order(:id).reduce(initial) { |state, move| state.apply(move) }
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
    bids.size < turn_order.size
  end

  def self.cache_key_for(game)
    last_id = game.moves.maximum(:id) || 0
    "game_state/#{game.id}/#{last_id}"
  end

  def turn_player_id
    game.players.order(:id).to_a[turn_player_index].id
  end

  def current_player
    Player.find(turn_player_id)
  end

  def game_over?
    alive_players > 1
  end

  private

  # TODO: hook
  def apply_bid(move)
    self.bids = bids.merge(move.player_id => move.value.to_i)
    self.turn_player_index = next_index(turn_player_index)
    self
  end

  def apply_card(move)
    self.current_trick = current_trick + [ [ move.player_id, move.value ] ]
    self.turn_player_index = next_index(turn_player_index)

    if current_trick.size == alive_players
      resolve_trick!
      advance_round! if round_over?
    end

    self
  end

  def resolve_trick!
    winner_id = sorted_trick.first
    self.tricks_won = tricks_won.merge(winner_id => tricks_won.fetch(winner_id, 0) + 1)
    self.current_trick = []
    self.turn_player_id = winner_id
  end

  def advance_round!
    self.lives = lives.merge(
      tricks_won.to_h { |pid, won| [ pid, lives[pid] - (won - bids.fetch(pid, 0)).abs ] }
    )
    self.round += 1
    self.bids = {}
    self.tricks_won = {}
    self.dealer_index = next_index(dealer_index)
    self.hand_size = RANK_ORDER.size / alive_players
  end

  def next_index(index)
    (index + 1) % alive_players
  end

  def alive_players
    lives.values.reject(&:zero?).count
  end

  def round_over?
    tricks_won.values.sum == hand_size
  end

  def sorted_trick
    current_trick.sort_by { |_, card| -RANK_ORDER[card] }
  end
end
