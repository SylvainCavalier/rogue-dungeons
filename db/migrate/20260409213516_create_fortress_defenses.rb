class CreateFortressDefenses < ActiveRecord::Migration[8.0]
  def change
    create_table :fortress_defenses do |t|
      t.references :character, null: false, foreign_key: true
      t.string :trap_key, null: false
      t.string :direction, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :fortress_defenses, [:character_id, :direction]
  end
end
