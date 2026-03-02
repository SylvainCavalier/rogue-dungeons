class CreateCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :characters do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.integer :vigueur, null: false
      t.integer :dexterite, null: false
      t.integer :intelligence, null: false
      t.integer :charisme, null: false
      t.integer :perception, null: false
      t.integer :current_hp, null: false
      t.integer :max_hp, null: false
      t.integer :current_mana, null: false, default: 0
      t.integer :max_mana, null: false, default: 0
      t.integer :xp, null: false, default: 0
      t.integer :gold, null: false, default: 50
      t.integer :current_floor, null: false, default: 0
      t.integer :day, null: false, default: 1
      t.integer :week, null: false, default: 1
      t.integer :month, null: false, default: 1
      t.integer :year, null: false, default: 1
      t.string :status
      t.integer :status_duration, default: 0
      t.string :activity
      t.integer :activity_days_left, default: 0
      t.jsonb :activity_data, default: {}
      t.jsonb :combat_state

      t.timestamps
    end
  end
end
