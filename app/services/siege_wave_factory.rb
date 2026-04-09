class SiegeWaveFactory
  class << self
    def build_for_week(total_weeks)
      wave_data = find_wave(total_weeks)
      enemies = wave_data["enemies"].flat_map do |entry|
        template = GameCatalog.siege_monster(entry["key"])
        Array.new(entry["count"]) { build_siege_monster(template, entry["key"]) }
      end
      scale_enemies(enemies, total_weeks)
    end

    private

    def find_wave(total_weeks)
      waves = GameCatalog.siege_waves
      wave = waves.find { |w| total_weeks >= w["week_range"][0] && total_weeks <= w["week_range"][1] }
      wave || waves.last
    end

    def build_siege_monster(template, key)
      unless template
        return fallback_monster
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

    def scale_enemies(enemies, total_weeks)
      return enemies if total_weeks <= 4

      scaling = 1 + (total_weeks - 4) * 0.05
      enemies.each do |e|
        e[:hp] = (e[:hp] * scaling).ceil
        e[:max_hp] = e[:hp]
        e[:xp_value] = (e[:xp_value] * scaling).ceil
        e[:gold_value] = (e[:gold_value] * scaling).ceil
      end
      enemies
    end

    def fallback_monster
      {
        key: "unknown",
        name: "Créature inconnue",
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
