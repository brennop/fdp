class AddTokenToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :token, :string, null: false
    add_index :players, :token, unique: true
  end
end
