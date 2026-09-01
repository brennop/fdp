
class Deck
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

  def self.shuffled(seed)
    RANK_ORDER.to_a.shuffle(random: Random.new(seed)).to_h
  end
end
