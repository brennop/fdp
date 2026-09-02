# frozen_string_literal: true

class Move < ApplicationRecord
  belongs_to :player
  belongs_to :game

  validate :legal_move

  after_create_commit :broadcast_state

  # should be the state up until now but if moves are immutable, it's only read
  # on creation, and we can assume game.state
  def state
    @state ||= GameState.for(self)
  end

  def prev_state
    prev&.state || GameState.initial(game)
  end

  def prev
    ancestors.last
  end

  def ancestors
    game.moves.where(ancestor_cond).order(id: :asc)
  end

  def cached?
    Rails.cache.exist?("game_state/#{id}")
  end

  private

  def legal_move
    state
  rescue Exceptions::IllegalMove => e
    errors.add(:base, e.message)
  end

  def broadcast_state
    game.players.each do |player|
      # the POST will aready render
      next if player == self.player

      player.broadcast_replace_to(
        "player_#{player.id}",
        target: "state",
        partial: "games/state",
        locals: { state:, game:, player: }
      )
    end
  end

  def ancestor_cond
    [ "id < ?", id ] if id?
  end
end
