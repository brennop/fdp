class AddIndexToGamesSeed < ActiveRecord::Migration[8.0]
  def change
    add_index :games, :seed
  end
end
