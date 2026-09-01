class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :seed
      t.string :status
      t.integer :starting_lives

      t.timestamps
    end
  end
end
