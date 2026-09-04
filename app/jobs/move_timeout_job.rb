class MoveTimeoutJob < ApplicationJob
  queue_as :default

  def perform(*args)
    move_id = args[0]

    move = Move.find(move_id)
    game = move.game

    return unless game.moves.last.id == move_id

    state = GameState.for(move)

    value = if state.bidding_phase?
      state.legal_bids.to_a.sample
    else
      state.hands[state.turn_player_id].sample
    end

    game.moves.create player_id: state.turn_player_id, value:
  end
end
