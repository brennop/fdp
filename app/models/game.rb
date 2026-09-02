class Game < ApplicationRecord
  has_many :players, -> { order(:id) }, dependent: :destroy
  has_many :moves

  enum :status, { lobby: 0, playing: 1, ended: 2 }

  def state
    return GameState.initial(self) if moves.empty?

    GameState.for(moves.last)
  end

  def to_param
    seed
  end

  def ready?
    players.where(ready: true).size >= 3
  end

  def start!
    self.status = :playing
    save
  end
end
