class CreateLearnedTechniques < ActiveRecord::Migration[8.0]
  def change
    create_table :learned_techniques do |t|
      t.references :character, null: false, foreign_key: true
      t.string :technique_key, null: false
      t.string :name, null: false
      t.string :category, null: false

      t.timestamps
    end

    add_index :learned_techniques, [:character_id, :technique_key], unique: true
  end
end
