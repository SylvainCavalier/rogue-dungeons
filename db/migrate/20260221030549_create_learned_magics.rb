class CreateLearnedMagics < ActiveRecord::Migration[8.0]
  def change
    create_table :learned_magics do |t|
      t.references :character, null: false, foreign_key: true
      t.string :magic_key, null: false
      t.string :name, null: false
      t.string :element, null: false
      t.integer :tier, null: false

      t.timestamps
    end

    add_index :learned_magics, [:character_id, :magic_key], unique: true
  end
end
