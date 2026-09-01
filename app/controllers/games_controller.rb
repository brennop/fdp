# frozen_string_literal: true

class GamesController < ApplicationController
  before_action :set_game
  before_action :set_current_player

  def show
  end

  def join
    player = @game.players.create!(name: params[:name])

    cookies.signed["player_token_#{@game.id}"] = {
      value: player.token,
      expires: 30.days
    }

    redirect_to game_path(@game)
  end

  def ready
    @current_player.update(ready: !@current_player.ready)

    @game.start! if @game.ready?

    redirect_to game_path(@game)
  end

  def move
    @move = @current_player.moves.build(move_params)
    @move.save

    render :show
  end

  private

  def set_game
    @game = Game.find_by(seed: params[:seed])
  end

  def set_current_player
    token = cookies.signed["player_token_#{@game.id}"]
    @current_player = @game.players.find_by(token: token)
  end

  def move_params
    params.require(:move).permit(:value, :game_id)
  end
end
