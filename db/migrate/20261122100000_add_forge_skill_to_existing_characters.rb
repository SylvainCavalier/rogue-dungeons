class AddForgeSkillToExistingCharacters < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      INSERT INTO skills (character_id, name, category, mastery, bonus, created_at, updated_at)
      SELECT c.id, 'Forge', 'vigueur', GREATEST(c.vigueur, 1), 0, NOW(), NOW()
      FROM characters c
      WHERE NOT EXISTS (
        SELECT 1 FROM skills s WHERE s.character_id = c.id AND s.name = 'Forge'
      )
    SQL
  end

  def down
    execute "DELETE FROM skills WHERE name = 'Forge'"
  end
end
