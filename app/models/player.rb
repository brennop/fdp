class Player < ApplicationRecord
  belongs_to :game
  has_many :moves, -> { order(:id) }, dependent: :destroy

  broadcasts_refreshes_to :game

  before_validation :generate_token, on: :create

  def in_turn?
    game.state.turn_player_id == id
  end

  def can_play?
    in_turn? and game.state.bids[id] != nil
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end
end
