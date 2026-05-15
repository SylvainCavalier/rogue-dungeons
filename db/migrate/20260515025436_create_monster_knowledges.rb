class CreateMonsterKnowledges < ActiveRecord::Migration[8.0]
  def change
    create_table :monster_knowledges do |t|
      t.references :character, null: false, foreign_key: true
      t.string :monster_key, null: false
      t.jsonb :revealed_keys, null: false, default: []
      t.timestamps
    end
    add_index :monster_knowledges, [:character_id, :monster_key], unique: true
  end
end
