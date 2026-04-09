class CreateSiegeLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :siege_logs do |t|
      t.references :character, null: false, foreign_key: true
      t.integer :siege_week, null: false
      t.string :attack_direction, null: false
      t.string :result, null: false
      t.integer :xp_gained, default: 0, null: false
      t.integer :gold_gained, default: 0, null: false
      t.jsonb :log_data, default: []
      t.jsonb :damage_dealt, default: {}
      t.timestamps
    end

    add_index :siege_logs, [:character_id, :siege_week]
  end
end
