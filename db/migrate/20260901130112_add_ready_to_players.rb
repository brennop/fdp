class AddReadyToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :ready, :boolean
  end
end
