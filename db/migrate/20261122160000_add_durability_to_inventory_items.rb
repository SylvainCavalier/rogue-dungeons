class AddDurabilityToInventoryItems < ActiveRecord::Migration[8.0]
  def change
    # Wear of weapons and armor (0..100): -1 per fight, -10 per lost fight, repaired at the forge.
    add_column :inventory_items, :durability, :integer, default: 100, null: false
  end
end
