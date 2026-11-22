class AddGuildRanksToCharacters < ActiveRecord::Migration[8.0]
  def change
    # 0 = not a member, then the index of the rank in config/catalog/guildes.yml (1 = apprenti…)
    add_column :characters, :warrior_rank, :integer, default: 0, null: false
    add_column :characters, :mage_rank, :integer, default: 0, null: false
  end
end
