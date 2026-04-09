class AddSiegeFieldsToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :watchtower_level, :integer, default: 0, null: false
    add_column :characters, :workshop_level, :integer, default: 0, null: false
    add_column :characters, :building_damage, :jsonb, default: {}, null: false
    add_column :characters, :siege_state, :jsonb
    add_column :characters, :total_sieges_won, :integer, default: 0, null: false
  end
end
