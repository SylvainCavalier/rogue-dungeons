class CreateCombatLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :combat_logs do |t|
      t.references :character, null: false, foreign_key: true
      t.integer :floor, null: false
      t.string :result, null: false
      t.jsonb :log_data, default: []
      t.integer :xp_gained, null: false, default: 0
      t.integer :gold_gained, null: false, default: 0

      t.timestamps
    end

    add_index :combat_logs, [:character_id, :floor]
  end
end
