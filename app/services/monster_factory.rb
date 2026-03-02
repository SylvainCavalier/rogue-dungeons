class MonsterFactory
  class << self
    def build_for_floor(floor_number)
      floor_data = GameCatalog.floor(floor_number)
      return fallback_encounter(floor_number) unless floor_data

      floor_data["enemies"].map do |enemy_entry|
        count = enemy_entry["count"] || 1
        name = enemy_entry["name"]
        monster_key = GameCatalog.monster_key_for_name(name)
        template = GameCatalog.monster(monster_key) if monster_key

        Array.new(count) { build_monster(template, name, monster_key) }
      end.flatten
    end

    private

    def build_monster(template, name, key)
      unless template
        return fallback_monster(name)
      end

      {
        key: key,
        name: template["name"],
        hp: template["hp"],
        max_hp: template["hp"],
        vigueur: stat_hash(template["vigueur"]),
        attack: stat_hash(template["attack"]),
        damage: stat_hash(template["damage"]),
        esquive: stat_hash(template["esquive"]),
        dr: stat_hash(template["dr"]),
        xp_value: template["xp_value"] || 5,
        gold_value: template["gold_value"] || 3,
        abilities: template["abilities"] || [],
        statuses: [],
        debuffs: {}
      }
    end

    def stat_hash(raw)
      return { mastery: 1, bonus: 0 } unless raw
      { mastery: raw["mastery"] || 1, bonus: raw["bonus"] || 0 }
    end

    def fallback_encounter(floor_number)
      count = [1, (floor_number / 10.0).ceil].min + rand(0..1)
      Array.new(count) { fallback_monster("Créature inconnue") }
    end

    def fallback_monster(name)
      {
        key: "unknown",
        name: name,
        hp: 5,
        max_hp: 5,
        vigueur: { mastery: 1, bonus: 0 },
        attack: { mastery: 1, bonus: 0 },
        damage: { mastery: 1, bonus: 0 },
        esquive: { mastery: 1, bonus: 0 },
        dr: { mastery: 0, bonus: 0 },
        xp_value: 5,
        gold_value: 3,
        abilities: [],
        statuses: [],
        debuffs: {}
      }
    end
  end
end
