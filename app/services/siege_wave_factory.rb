class SiegeWaveFactory
  class << self
    # Core enemies of the week's wave, completed with its `fill` monster up to
    # the wave size (grows with the weeks, siege.yml `wave_scaling`), then scaled.
    def build_for_week(total_weeks)
      wave_data = find_wave(total_weeks)
      keys = wave_data["enemies"].flat_map { |entry| [entry["key"]] * entry["count"].to_i }
      fill = wave_data["fill"] || keys.first
      keys += [fill] * (wave_size(total_weeks) - keys.size) if fill
      enemies = keys.map { |key| build_siege_monster(GameCatalog.siege_monster(key), key) }
      scale_enemies(enemies, total_weeks)
    end

    def wave_size(total_weeks)
      cfg = GameCatalog.siege_wave_scaling
      every = [cfg["extra_enemy_every_weeks"].to_i, 1].max
      size = cfg.fetch("base_size", 2).to_i + ([total_weeks, 1].max - 1) / every
      [size, cfg.fetch("max_enemies", 8).to_i].min
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
        vitesse: stat_hash(template["vitesse"]),
        xp_value: template["xp_value"] || 5,
        gold_value: template["gold_value"] || 3,
        abilities: template["abilities"] || [],
        ability_chance: template["ability_chance"],
        statuses: [],
        debuffs: {}
      }
    end

    def stat_hash(raw)
      return { mastery: 1, bonus: 0 } unless raw
      { mastery: raw["mastery"] || 1, bonus: raw["bonus"] || 0 }
    end

    # PV +hp_percent_per_week % per week after hp_scaling_from_week, and +1 attack /
    # damage bonus every stat_bonus_every_weeks weeks (3 bonus = +1D).
    def scale_enemies(enemies, total_weeks)
      cfg = GameCatalog.siege_wave_scaling
      from_week = cfg.fetch("hp_scaling_from_week", 4).to_i
      hp_scaling = 1 + [total_weeks - from_week, 0].max * cfg.fetch("hp_percent_per_week", 5).to_f / 100
      every = cfg["stat_bonus_every_weeks"].to_i
      stat_bonus = every.positive? ? total_weeks / every : 0

      enemies.each do |e|
        e[:hp] = (e[:hp] * hp_scaling).ceil
        e[:max_hp] = e[:hp]
        next unless stat_bonus.positive?

        e[:attack] = add_bonus(e[:attack], stat_bonus)
        e[:damage] = add_bonus(e[:damage], stat_bonus)
      end
      enemies
    end

    def add_bonus(stat, extra)
      total = stat[:bonus] + extra
      { mastery: stat[:mastery] + total / 3, bonus: total % 3 }
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
        vitesse: { mastery: 1, bonus: 0 },
        xp_value: 5,
        gold_value: 3,
        abilities: [],
        statuses: [],
        debuffs: {}
      }
    end
  end
end
