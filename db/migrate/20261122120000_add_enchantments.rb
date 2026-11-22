class AddEnchantments < ActiveRecord::Migration[8.0]
  def change
    add_column :inventory_items, :enchantment, :jsonb
    add_column :characters, :soul_stones, :integer, default: 0, null: false
  end
end
