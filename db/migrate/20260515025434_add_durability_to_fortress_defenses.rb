class AddDurabilityToFortressDefenses < ActiveRecord::Migration[8.0]
  def change
    add_column :fortress_defenses, :durability, :integer, default: 5, null: false
    add_column :fortress_defenses, :max_durability, :integer, default: 5, null: false
  end
end
