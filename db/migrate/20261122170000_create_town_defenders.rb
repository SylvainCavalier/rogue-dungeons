class CreateTownDefenders < ActiveRecord::Migration[8.0]
  def up
    # Defenders recruited at the warriors guild; direction nil = in reserve (not posted at a gate).
    create_table :town_defenders do |t|
      t.references :character, null: false, foreign_key: true
      t.string :defender_key, null: false
      t.string :direction
      t.timestamps
    end

    # The fortress level now sets the trap capacity (it used to be the workshop's)
    # and the number of defenders. Existing characters keep their trap capacity.
    add_column :characters, :fortress_level, :integer, default: 0, null: false
    # Weekly recruitment limit: week of the last recruit and recruits made that week.
    add_column :characters, :recruit_week, :integer, default: 0, null: false
    add_column :characters, :recruits_this_week, :integer, default: 0, null: false

    execute "UPDATE characters SET fortress_level = workshop_level"
  end

  def down
    remove_column :characters, :recruits_this_week
    remove_column :characters, :recruit_week
    remove_column :characters, :fortress_level
    drop_table :town_defenders
  end
end
