# frozen_string_literal: true

class GamesController < ApplicationController
  before_action :set_game
  before_action :set_current_player

  def show
    @state = GameState.for(@game)
  end

  def join
    player = @game.players.create!(name: params[:name])

    cookies.signed["player_token_#{@game.id}"] = {
      value: player.token,
      expires: 30.days
    }

    redirect_to game_path(@game)
  end

  private

  def set_game
    @game = Game.find_by(seed: params[:seed])
  end

  def set_current_player
    token = cookies.signed["player_token_#{@game.id}"]
    @current_player = @game.players.find_by(token: token)
  end
end
