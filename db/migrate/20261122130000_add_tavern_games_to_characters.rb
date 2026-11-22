class AddTavernGamesToCharacters < ActiveRecord::Migration[8.0]
  def change
    # { "arm_wrestling" => { "wins" => 3, "last_day" => 52 }, "drinking" => {...} }
    add_column :characters, :tavern_games, :jsonb, default: {}, null: false
  end
end
