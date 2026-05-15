module Api
  class SiegeController < BaseController
    before_action :require_character!

    # GET /api/siege/fortress
    def fortress
      char = current_character
      workshop_data = GameCatalog.workshop_level_data(char.workshop_level)
      max_traps = workshop_data ? (workshop_data["max_traps_per_direction"] || 1) : 1

      grouped = char.fortress_defenses.order(:direction, :position).group_by(&:direction)
      defenses_json = FortressDefense::DIRECTIONS.index_with do |dir|
        defenses = (grouped[dir] || []).sort_by(&:position)
        synergies = predicted_synergies(defenses)
        defenses.map.with_index do |d, idx|
          trap_data = GameCatalog.siege_trap(d.trap_key)
          {
            id: d.id,
            trap_key: d.trap_key,
            position: idx,
            durability: d.durability,
            max_durability: d.max_durability,
            broken: d.broken?,
            damaged: d.damaged?,
            repair_cost: d.repair_cost,
            well_placed: well_placed?(d, trap_data, defenses),
            trap: trap_data
          }
        end.then { |list| { defenses: list, synergies: synergies } }
      end

      available_traps = GameCatalog.all_siege_traps.select do |_key, trap|
        trap["workshop_level"] <= char.workshop_level
      end

      total_repair = char.fortress_defenses.sum(&:repair_cost)

      render json: {
        defenses: defenses_json,
        available_traps: available_traps,
        synergies_catalog: GameCatalog.siege_synergies,
        gold: char.gold,
        workshop_level: char.workshop_level,
        max_traps_per_direction: max_traps,
        total_repair_cost: total_repair
      }
    end

    # POST /api/siege/fortress/place
    def place_trap
      char = current_character
      trap_key = params[:trap_key]
      direction = params[:direction]

      trap_data = GameCatalog.siege_trap(trap_key)
      return render json: { error: "Piège inconnu" }, status: :unprocessable_entity unless trap_data

      unless FortressDefense::DIRECTIONS.include?(direction)
        return render json: { error: "Direction invalide" }, status: :unprocessable_entity
      end

      if trap_data["workshop_level"] > char.workshop_level
        return render json: { error: "Atelier insuffisant pour ce piège" }, status: :unprocessable_entity
      end

      workshop_data = GameCatalog.workshop_level_data(char.workshop_level)
      max_traps = workshop_data ? (workshop_data["max_traps_per_direction"] || 1) : 1
      current_count = char.fortress_defenses.where(direction: direction).count

      if current_count >= max_traps
        return render json: { error: "Maximum de pièges atteint dans cette direction (#{max_traps})" }, status: :unprocessable_entity
      end

      cost = trap_data["cost"] || 0
      if char.gold < cost
        return render json: { error: "Pas assez d'or (#{char.gold}/#{cost})" }, status: :unprocessable_entity
      end

      max_dur = trap_data["max_durability"] || 5
      char.update!(gold: char.gold - cost)
      char.fortress_defenses.create!(
        trap_key: trap_key,
        direction: direction,
        position: current_count,
        durability: max_dur,
        max_durability: max_dur
      )

      render json: {
        message: "#{trap_data["name"]} placé(e) au #{direction} !",
        gold: char.gold
      }
    end

    # POST /api/siege/fortress/repair
    def repair_defense
      char = current_character
      defense = char.fortress_defenses.find_by(id: params[:id])
      return render json: { error: "Défense introuvable" }, status: :not_found unless defense
      return render json: { error: "Cette défense est intacte" }, status: :unprocessable_entity unless defense.damaged?

      cost = defense.repair_cost
      if char.gold < cost
        return render json: { error: "Pas assez d'or (#{char.gold}/#{cost})" }, status: :unprocessable_entity
      end

      char.update!(gold: char.gold - cost)
      defense.update!(durability: defense.max_durability)

      trap = GameCatalog.siege_trap(defense.trap_key)
      render json: {
        message: "#{trap ? trap['name'] : defense.trap_key} réparé(e) ! (-#{cost} or)",
        gold: char.gold
      }
    end

    # POST /api/siege/fortress/repair_all
    def repair_all_defenses
      char = current_character
      damaged = char.fortress_defenses.select(&:damaged?)
      return render json: { error: "Aucune défense à réparer" }, status: :unprocessable_entity if damaged.empty?

      total_cost = damaged.sum(&:repair_cost)
      if char.gold < total_cost
        return render json: { error: "Pas assez d'or (#{char.gold}/#{total_cost})" }, status: :unprocessable_entity
      end

      FortressDefense.transaction do
        char.update!(gold: char.gold - total_cost)
        damaged.each { |d| d.update!(durability: d.max_durability) }
      end

      render json: {
        message: "#{damaged.size} défense(s) réparée(s) ! (-#{total_cost} or)",
        gold: char.gold
      }
    end

    # POST /api/siege/fortress/reorder
    # body: { id, direction: "up" | "down" }
    def reorder_defense
      char = current_character
      defense = char.fortress_defenses.find_by(id: params[:id])
      return render json: { error: "Défense introuvable" }, status: :not_found unless defense

      siblings = char.fortress_defenses.where(direction: defense.direction).order(:position).to_a
      idx = siblings.index(defense)
      return render json: { error: "Position invalide" }, status: :unprocessable_entity unless idx

      neighbor_idx = params[:move] == "up" ? idx - 1 : idx + 1
      return render json: { error: "Déjà à l'extrémité" }, status: :unprocessable_entity if neighbor_idx < 0 || neighbor_idx >= siblings.size

      neighbor = siblings[neighbor_idx]
      FortressDefense.transaction do
        a, b = defense.position, neighbor.position
        # éviter conflit d'index unique éventuel via valeur tampon
        defense.update!(position: -1)
        neighbor.update!(position: a)
        defense.update!(position: b)
      end

      render json: { message: "Défense déplacée" }
    end

    # DELETE /api/siege/fortress/remove
    def remove_trap
      char = current_character
      defense = char.fortress_defenses.find_by(id: params[:id])

      unless defense
        return render json: { error: "Défense introuvable" }, status: :not_found
      end

      trap_data = GameCatalog.siege_trap(defense.trap_key)
      refund = trap_data ? (trap_data["cost"] || 0) / 2 : 0
      char.update!(gold: char.gold + refund)
      defense.destroy!

      render json: {
        message: "Défense retirée. #{refund} or récupéré.",
        gold: char.gold
      }
    end

    # GET /api/siege/watchtower
    def watchtower
      char = current_character
      level_data = GameCatalog.watchtower_level_data(char.watchtower_level)
      next_level_data = GameCatalog.watchtower_level_data(char.watchtower_level + 1)

      intel = WatchtowerIntelService.new(char).predict

      render json: {
        level: char.watchtower_level,
        level_data: level_data,
        intel: intel,
        upgrade_cost: next_level_data ? next_level_data["upgrade_cost"] : nil,
        can_upgrade: next_level_data.present? && char.gold >= (next_level_data["upgrade_cost"] || 0),
        gold: char.gold
      }
    end

    # POST /api/siege/watchtower/upgrade
    def upgrade_watchtower
      char = current_character
      next_level = char.watchtower_level + 1
      next_data = GameCatalog.watchtower_level_data(next_level)

      unless next_data
        return render json: { error: "Niveau maximum atteint" }, status: :unprocessable_entity
      end

      cost = next_data["upgrade_cost"] || 0
      if char.gold < cost
        return render json: { error: "Pas assez d'or (#{char.gold}/#{cost})" }, status: :unprocessable_entity
      end

      if char.building_destroyed?("watchtower")
        return render json: { error: "La vigie est détruite, réparez-la d'abord" }, status: :unprocessable_entity
      end

      char.update!(gold: char.gold - cost, watchtower_level: next_level)

      render json: {
        message: "Vigie améliorée au niveau #{next_level} !",
        level: next_level,
        level_data: next_data,
        gold: char.gold
      }
    end

    # GET /api/siege/workshop
    def workshop
      char = current_character
      level_data = GameCatalog.workshop_level_data(char.workshop_level)
      next_level_data = GameCatalog.workshop_level_data(char.workshop_level + 1)

      all_traps = GameCatalog.all_siege_traps.map do |key, trap|
        trap.merge("key" => key, "unlocked" => trap["workshop_level"] <= char.workshop_level)
      end

      render json: {
        level: char.workshop_level,
        level_data: level_data,
        upgrade_cost: next_level_data ? next_level_data["upgrade_cost"] : nil,
        can_upgrade: next_level_data.present? && char.gold >= (next_level_data["upgrade_cost"] || 0),
        traps: all_traps,
        gold: char.gold
      }
    end

    # POST /api/siege/workshop/upgrade
    def upgrade_workshop
      char = current_character
      next_level = char.workshop_level + 1
      next_data = GameCatalog.workshop_level_data(next_level)

      unless next_data
        return render json: { error: "Niveau maximum atteint" }, status: :unprocessable_entity
      end

      cost = next_data["upgrade_cost"] || 0
      if char.gold < cost
        return render json: { error: "Pas assez d'or (#{char.gold}/#{cost})" }, status: :unprocessable_entity
      end

      if char.building_destroyed?("workshop")
        return render json: { error: "L'atelier est détruit, réparez-le d'abord" }, status: :unprocessable_entity
      end

      char.update!(gold: char.gold - cost, workshop_level: next_level)

      render json: {
        message: "Atelier amélioré au niveau #{next_level} !",
        level: next_level,
        level_data: next_data,
        gold: char.gold
      }
    end

    # POST /api/siege/start
    def start
      char = current_character

      unless char.siege_pending?
        return render json: { error: "Aucun siège en attente" }, status: :unprocessable_entity
      end

      service = SiegeService.new(char)
      result = service.prepare_siege

      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        render json: result
      end
    end

    # GET /api/siege/combat
    def combat
      char = current_character

      unless char.in_siege? && char.in_combat?
        return render json: { error: "Aucun siège en cours" }, status: :not_found
      end

      service = SiegeService.new(char)
      render json: service.siege_snapshot
    end

    # POST /api/siege/combat/action
    def action
      char = current_character

      unless char.in_siege? && char.in_combat?
        return render json: { error: "Aucun siège en cours" }, status: :not_found
      end

      service = SiegeService.new(char)
      result = service.player_action(
        params[:action_type],
        key: params[:key],
        target: params[:target],
        item_id: params[:item_id]
      )

      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        render json: result
      end
    end

    # GET /api/siege/buildings
    def buildings
      char = current_character
      buildings_data = SiegeService::BUILDINGS.map do |key|
        repair_info = GameCatalog.building_repair_cost(key)
        damage_level = char.building_damage[key].to_i
        {
          key: key,
          name: repair_info ? repair_info["name"] : key.capitalize,
          damage_level: damage_level,
          status: damage_status(damage_level),
          repair_cost: damage_level > 0 ? (repair_info ? repair_info["cost_per_level"] : 50) : 0
        }
      end

      render json: {
        buildings: buildings_data,
        gold: char.gold,
        any_damaged: char.building_damage.values.any? { |v| v.to_i > 0 }
      }
    end

    # POST /api/siege/buildings/repair
    def repair
      char = current_character
      building_key = params[:building_key]

      unless SiegeService::BUILDINGS.include?(building_key)
        return render json: { error: "Bâtiment inconnu" }, status: :unprocessable_entity
      end

      damage_level = char.building_damage[building_key].to_i
      if damage_level <= 0
        return render json: { error: "Ce bâtiment n'est pas endommagé" }, status: :unprocessable_entity
      end

      repair_info = GameCatalog.building_repair_cost(building_key)
      cost = repair_info ? repair_info["cost_per_level"] : 50

      if char.gold < cost
        return render json: { error: "Pas assez d'or (#{char.gold}/#{cost})" }, status: :unprocessable_entity
      end

      new_damage = char.building_damage.dup
      new_damage[building_key] = damage_level - 1
      char.update!(gold: char.gold - cost, building_damage: new_damage)

      render json: {
        message: "#{repair_info ? repair_info["name"] : building_key} réparé(e) !",
        gold: char.gold,
        damage_level: damage_level - 1
      }
    end

    # GET /api/siege/status
    def status
      char = current_character
      render json: {
        in_siege: char.in_siege?,
        siege_pending: char.siege_pending?,
        siege_state: char.siege_state,
        total_sieges_won: char.total_sieges_won,
        days_until_siege: days_until_siege(char)
      }
    end

    private

    def damage_status(level)
      case level
      when 0 then "intact"
      when 1 then "endommagé"
      else "détruit"
      end
    end

    def days_until_siege(char)
      Character::DAYS_PER_WEEK - char.day
    end

    def predicted_synergies(defenses)
      active_defenses = defenses.reject(&:broken?)
      return [] if active_defenses.empty?

      type_counts = active_defenses.map { |d| GameCatalog.siege_trap(d.trap_key)&.dig("type") }.compact.tally
      GameCatalog.siege_synergies.filter_map do |key, syn|
        required_types = syn["requires_types"] || []
        required_counts = syn["requires_count"] || {}
        next nil if required_types.any? && !required_types.all? { |t| type_counts[t].to_i >= 1 }
        next nil if required_counts.any? { |t, n| type_counts[t].to_i < n }

        { key: key, name: syn["name"], description: syn["description"] }
      end
    end

    def well_placed?(defense, trap_data, siblings)
      return false unless trap_data
      role = trap_data["role"]
      return false if role.nil? || role == "flex"

      sorted = siblings.sort_by(&:position)
      case role
      when "front" then defense.id == sorted.first.id
      when "back"  then defense.id == sorted.last.id
      else false
      end
    end
  end
end
