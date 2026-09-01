# frozen_string_literal: true

# ♠	♥	♦	♣
class Move < ApplicationRecord
  belongs_to :player
  belongs_to :game

  validates :value, presence: true
  validates :player, comparison: { equal_to: :current_turn_player }
  validates :value, inclusion: { in: :legal_values }

  after_create_commit :broadcast_state

  def bid
    Integer(value, exception: false)
  end

  def bid?
    bid != nil
  end

  # should be the state up until now but if moves are immutable, it's only read
  # on creation, and we can assume game.state
  def state
    game.state
  end

  private

  def current_turn_player
    state.current_player
  end

  def legal_values
    state.bidding_phase? ? legal_bids : legal_cards
  end

  # TODO: exclude state.hook from this
  def legal_bids
    (0..state.hand_size).map(&:to_s)
  end

  def legal_cards
    state.hands[player.id]
  end

  def broadcast_state
    state.broadcast_replace_to(
      "state_game_#{state.game_id}",
      target: "state",
      partial: "games/state",
      locals: { state:, game: }
    )

    Player.where(id: state.alive_players).each do |player|
      player.broadcast_replace_to(
        "form_player_#{player.id}",
        target: "move_form",
        partial: "games/form",
        locals: { state:, game:, player: }
      )
    end
  end
end
