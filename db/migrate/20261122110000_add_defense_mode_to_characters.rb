class AddDefenseModeToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :defense_mode, :string, null: false, default: "esquive"
  end
end
