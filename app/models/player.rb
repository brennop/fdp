class Player < ApplicationRecord
  belongs_to :game
  has_many :moves, -> { order(:id) }, dependent: :destroy
end
