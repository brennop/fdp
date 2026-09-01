class Game < ApplicationRecord
  has_many :players, -> { order(:id) }, dependent: :destroy
  has_many :moves

  def state
    GameState.for(self)
  end
end
