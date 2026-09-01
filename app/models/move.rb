# frozen_string_literal: true

# ♠	♥	♦	♣
class Move < ApplicationRecord
  belongs_to :player
  belongs_to :game

  # validate
  # TODO: validate game phase
  validates :player, comparison: { equal_to: -> { state.current_player } }

  # bid validations
  validates :bid, comparison: { greater_than_or_equal_to: 0, less_than_or_equal_to: -> { state.hand_size } }
  validates :bid, comparison: { other_than: -> { state.hook } }, if: -> { state.hook.present? }

  def bid
    Integer(value, exception: false)
  end

  def bid?
    bid != nil
  end

  # should be the state up until now
  # but if moves are immutable, it's only read on creation, and we can assume
  # game_state
  def state
    game.state
  end
end
