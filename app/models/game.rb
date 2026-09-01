class Game < ApplicationRecord
  has_many :players, -> { order(:id) }, dependent: :destroy
  has_many :moves

  def state
    GameState.for(self)
  end

  def to_param
    seed
  end
end
