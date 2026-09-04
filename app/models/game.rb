class Game < ApplicationRecord
  has_many :players, -> { order(:id) }, dependent: :destroy
  has_many :moves

  enum :status, { lobby: 0, playing: 1, ended: 2 }

  def state
    @state ||= moves.empty? ? GameState.initial(self) : GameState.for(moves.last)
  end

  def to_param
    seed
  end

  def ready?
    players.size >= 3 && players.where(ready: false).empty?
  end

  def start!
    self.status = :playing
    save
  end
end
