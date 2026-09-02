module CardHelper
  CARDS = {
  # Spades
  "AS" => "🂡", "2S" => "🂢", "3S" => "🂣", "4S" => "🂤",
  "5S" => "🂥", "6S" => "🂦", "7S" => "🂧", "8S" => "🂨",
  "9S" => "🂩", "10S" => "🂪", "JS" => "🂫", "QS" => "🂭", "KS" => "🂮",

  # Hearts
  "AH" => "🂱", "2H" => "🂲", "3H" => "🂳", "4H" => "🂴",
  "5H" => "🂵", "6H" => "🂶", "7H" => "🂷", "8H" => "🂸",
  "9H" => "🂹", "10H" => "🂺", "JH" => "🂻", "QH" => "🂽", "KH" => "🂾",

  # Diamonds
  "AD" => "🃁", "2D" => "🃂", "3D" => "🃃", "4D" => "🃄",
  "5D" => "🃅", "6D" => "🃆", "7D" => "🃇", "8D" => "🃈",
  "9D" => "🃉", "10D" => "🃊", "JD" => "🃋", "QD" => "🃍", "KD" => "🃎",

  # Clubs
  "AC" => "🃑", "2C" => "🃒", "3C" => "🃓", "4C" => "🃔",
  "5C" => "🃕", "6C" => "🃖", "7C" => "🃗", "8C" => "🃘",
  "9C" => "🃙", "10C" => "🃚", "JC" => "🃛", "QC" => "🃝", "KC" => "🃞"
  }

  def unicode_for(card)
    CARDS[card]
  end

  def color_for(card)
    case card.last
    when "S"
      "text-black-900"
    when "C"
      "text-blue-700"
    when "D"
      "text-orange-700"
    when "H"
      "text-red-700"
    end
  end

  def short_for(card)
    case card.last
    when "S"
      card.first + "♠"
    when "C"
      card.first + "♣"
    when "D"
      card.first + "♦"
    when "H"
      card.first + "♥"
    end
  end
end
