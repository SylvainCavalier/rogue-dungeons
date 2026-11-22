# Town defenders (config/catalog/siege.yml `defenders` / `recruitment`):
# recruited at the warriors guild (a limited number per week, total capped by
# the fortress level), posted at a gate from the fortress, and fighting as
# allies when that gate is attacked (SiegeService#prepare_siege).
class DefenderService
  attr_reader :character

  def initialize(character)
    @character = character
  end

  # Ally hash for CombatService (same shape as a summoned creature).
  def self.build_ally(defender)
    data = defender.data
    return nil unless data

    dice = ->(h) { h ? { mastery: h["mastery"].to_i, bonus: h["bonus"].to_i } : { mastery: 1, bonus: 0 } }
    hp = data["hp"].to_i
    {
      key: defender.defender_key, name: data["name"], hp: hp, max_hp: hp,
      attack: dice.(data["attack"]), damage: dice.(data["damage"]), esquive: dice.(data["esquive"]),
      vigueur: dice.(data["vigueur"]), dr: dice.(data["dr"]), heal: data["heal"] && dice.(data["heal"]),
      taunt: data["taunt"].to_i, role: data["role"] || "attack", damage_kind: "physical",
      aoe: false, rebirth: false, status_chance: 0, status_duration: 2,
      summoned_turn: nil, round_attacks: 0,
      defender: true, defender_id: defender.id, image_dir: "defenders"
    }
  end

  def capacity
    GameCatalog.fortress_level_data(character.fortress_level)&.dig("max_defenders").to_i
  end

  def recruits_per_week
    GameCatalog.recruitment_data.fetch("recruits_per_week", 2).to_i
  end

  def recruits_left
    used = character.recruit_week == character.total_weeks_elapsed ? character.recruits_this_week : 0
    [recruits_per_week - used, 0].max
  end

  def required_rank(data)
    data["guild_rank"] ? GuildRankService.rank_index("warriors", data["guild_rank"]) : 0
  end

  def recruit(key)
    data = GameCatalog.defender(key)
    return error("Défenseur inconnu") unless data
    return error("Impossible pendant un siège") if character.in_siege?
    return error("La guilde des guerriers est détruite, réparez-la d'abord") if character.building_destroyed?("guild")

    rank = required_rank(data)
    if character.warrior_rank < rank
      return error("Rang #{GuildRankService.rank_name('warriors', rank)} de la guilde requis")
    end
    return error("Plus de recrue disponible cette semaine (#{recruits_per_week} par semaine)") unless recruits_left.positive?
    if character.town_defenders.count >= capacity
      return error("Capacité de la forteresse atteinte (#{capacity} défenseurs) : améliorez-la")
    end

    cost = data["cost"].to_i
    return error("Pas assez d'or (#{character.gold}/#{cost})") if character.gold < cost

    week = character.total_weeks_elapsed
    used = character.recruit_week == week ? character.recruits_this_week : 0
    TownDefender.transaction do
      character.update!(gold: character.gold - cost, recruit_week: week, recruits_this_week: used + 1)
      character.town_defenders.create!(defender_key: key)
    end
    { success: true, message: "#{data['name']} rejoint la défense de la ville ! Postez-le à une porte depuis la forteresse." }
  end

  def dismiss(id)
    defender = character.town_defenders.find_by(id: id)
    return error("Défenseur introuvable") unless defender
    return error("Impossible pendant un siège") if character.in_siege?

    defender.destroy!
    { success: true, message: "#{defender.name} quitte la garde de la ville." }
  end

  # direction: a gate, or blank to send the defender back to the reserve.
  def station(id, direction)
    defender = character.town_defenders.find_by(id: id)
    return error("Défenseur introuvable") unless defender
    return error("Impossible pendant un siège") if character.in_siege?

    direction = direction.presence
    return error("Direction invalide") if direction && !FortressDefense::DIRECTIONS.include?(direction)

    defender.update!(direction: direction)
    message = direction ? "#{defender.name} est posté(e) à la porte #{direction}." : "#{defender.name} passe en réserve."
    { success: true, message: message }
  end

  def defenders_json
    character.town_defenders.order(:created_at, :id).map do |d|
      data = d.data || {}
      { id: d.id, key: d.defender_key, name: d.name, direction: d.direction, stats: stats_for(data) }
    end
  end

  # Payload for the recruitment tab of the guild.
  def info
    {
      recruits_left: recruits_left,
      recruits_per_week: recruits_per_week,
      capacity: capacity,
      count: character.town_defenders.count,
      gold: character.gold,
      guild_destroyed: character.building_destroyed?("guild"),
      catalog: GameCatalog.all_defenders.map do |key, data|
        rank = required_rank(data)
        {
          key: key, name: data["name"], description: data["description"], cost: data["cost"].to_i,
          required_rank_name: rank.positive? ? GuildRankService.rank_name("warriors", rank) : nil,
          rank_met: character.warrior_rank >= rank, stats: stats_for(data)
        }
      end,
      defenders: defenders_json
    }
  end

  private

  def stats_for(data)
    note = ->(h) { h ? DiceRoller.notation(h["mastery"].to_i, h["bonus"].to_i) : nil }
    {
      hp: data["hp"].to_i, role: data["role"] || "attack", taunt: data["taunt"].to_i,
      attack: note.(data["attack"]), damage: note.(data["damage"]), heal: note.(data["heal"]),
      esquive: note.(data["esquive"]),
      resistance: data["vigueur"] && data["dr"] &&
        DiceRoller.notation(data["vigueur"]["mastery"].to_i + data["dr"]["mastery"].to_i,
                            data["vigueur"]["bonus"].to_i + data["dr"]["bonus"].to_i)
    }
  end

  def error(message)
    { success: false, error: message }
  end
end
