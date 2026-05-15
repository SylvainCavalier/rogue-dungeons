class AddTowerSessionActiveToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :tower_session_active, :boolean, default: false, null: false
  end
end
