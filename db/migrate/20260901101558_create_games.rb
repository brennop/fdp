class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :seed
      t.integer :status, default: 0, null: false
      t.integer :starting_lives, default: 5

      t.timestamps
    end
  end
end
