class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false
      t.integer :mastery, null: false, default: 1
      t.integer :bonus, null: false, default: 0

      t.timestamps
    end

    add_index :skills, [:character_id, :name], unique: true
  end
end
