class CreateInventoryItems < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_items do |t|
      t.references :character, null: false, foreign_key: true
      t.string :item_key, null: false
      t.string :item_type, null: false
      t.integer :quantity, null: false, default: 1
      t.boolean :equipped, null: false, default: false
      t.string :slot

      t.timestamps
    end

    add_index :inventory_items, [:character_id, :item_key]
  end
end
