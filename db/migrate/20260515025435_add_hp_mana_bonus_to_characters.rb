class AddHpManaBonusToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :bonus_max_hp, :integer, default: 0, null: false
    add_column :characters, :bonus_max_mana, :integer, default: 0, null: false
  end
end
