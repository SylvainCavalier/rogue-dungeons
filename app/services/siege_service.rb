class SiegeService
  DIRECTIONS = FortressDefense::DIRECTIONS
  BUILDINGS = %w[shop academy guild forge watchtower workshop].freeze

  attr_reader :character

  def initialize(character)
    @character = character
  end

  # --- Préparation du siège ---

  def prepare_siege
    siege_data = character.siege_state
    return { error: "Aucun siège en attente" } unless siege_data && siege_data["pending"]

    siege_week = siege_data["siege_week"] || character.total_weeks_elapsed
    attack_direction = determine_attack_direction(siege_week)

    # Générer les ennemis
    enemies = SiegeWaveFactory.build_for_week(siege_week)

    # Récupérer les défenses non cassées dans la direction attaquée
    traps = character.fortress_defenses.where(direction: attack_direction).order(:position).to_a
    active_traps = traps.reject(&:broken?)
    broken_traps = traps.select(&:broken?)

    # Calculer synergies et bonus positionnels
    synergy_state = compute_synergies(active_traps)

    # Appliquer les effets des pièges (avec synergies et positions)
    trap_log = apply_trap_effects(active_traps, enemies, synergy_state)
    broken_traps.each do |d|
      td = GameCatalog.siege_trap(d.trap_key)
      trap_log << "#{td ? td['name'] : d.trap_key} est cassé(e) et n'a aucun effet."
    end

    # Calculer les bonus DR des pièges de type barrier (+ bonus synergie/position)
    barrier_dr_bonus = active_traps.sum do |d|
      trap_data = GameCatalog.siege_trap(d.trap_key)
      next 0 unless trap_data && trap_data["type"] == "barrier"

      base = trap_data["dr_bonus"] || 0
      pos_bonus = position_bonus?(d, trap_data) ? 1 : 0
      (base + pos_bonus) * synergy_state[:dr_multiplier]
    end
    barrier_dr_bonus = barrier_dr_bonus.round + synergy_state[:dr_flat]

    # Construire le combat state (compatible avec CombatService)
    combat_state = {
      "floor" => 0,
      "turn" => 0,
      "player" => {
        "hp" => character.current_hp,
        "max_hp" => character.max_hp,
        "mana" => character.current_mana,
        "max_mana" => character.max_mana
      },
      "enemies" => enemies.map { |e| e.deep_stringify_keys },
      "log" => trap_log + ["Le siège commence !"],
      "status" => "active",
      "player_statuses" => [],
      "player_debuffs" => {}
    }

    # Stocker le siege state
    character.update!(
      siege_state: {
        "pending" => false,
        "siege_week" => siege_week,
        "attack_direction" => attack_direction,
        "barrier_dr_bonus" => barrier_dr_bonus,
        "active_synergies" => synergy_state[:active_keys]
      },
      combat_state: combat_state
    )

    siege_snapshot
  end

  # --- Actions de combat ---

  def player_action(action_type, params = {})
    return { error: "Aucun siège en cours" } unless character.in_siege? && character.in_combat?

    # Sauvegarder les infos de siège avant que CombatService ne les efface
    siege_data_backup = character.siege_state.dup

    service = CombatService.new(character)
    result = service.player_action(action_type, params)

    # Vérifier si le combat est terminé
    if result[:status] == "victory"
      character.reload
      @character = character
      finish_siege(:victory, result, siege_data_backup)
    elsif result[:status] == "defeat"
      character.reload
      @character = character
      finish_siege(:defeat, result, siege_data_backup)
    end

    siege_info_data = character.in_siege? ? siege_info : { siege: true, siege_week: siege_data_backup["siege_week"], attack_direction: siege_data_backup["attack_direction"] }
    result.merge(siege_info_data)
  end

  # --- Snapshot ---

  def siege_snapshot
    return nil unless character.in_siege?

    combat_service = CombatService.new(character)
    snapshot = combat_service.combat_snapshot
    return { error: "Aucun combat en cours" } unless snapshot

    snapshot.merge(siege_info)
  end

  private

  def determine_attack_direction(siege_week)
    seed = siege_week * 7 + character.id
    DIRECTIONS[seed % DIRECTIONS.length]
  end

  # Calcule les synergies actives et leurs effets cumulés
  def compute_synergies(traps)
    state = {
      active_keys: [],
      damage_multiplier: 1.0,
      damage_flat: 0,
      dr_multiplier: 1.0,
      dr_flat: 0,
      esquive_flat: 0,
      attack_flat: 0
    }
    return state if traps.empty?

    types_present = traps.map { |t| GameCatalog.siege_trap(t.trap_key)&.dig("type") }.compact
    type_counts = types_present.tally

    GameCatalog.siege_synergies.each do |key, syn|
      required_types = syn["requires_types"] || []
      required_counts = syn["requires_count"] || {}

      next if required_types.any? && !required_types.all? { |t| type_counts[t].to_i >= 1 }
      next if required_counts.any? { |t, n| type_counts[t].to_i < n }

      state[:active_keys] << key
      effects = syn["effects"] || {}
      state[:damage_multiplier] *= effects["damage_multiplier"] if effects["damage_multiplier"]
      state[:damage_flat] += effects["damage_bonus"].to_i
      state[:dr_multiplier] *= effects["dr_multiplier"] if effects["dr_multiplier"]
      state[:dr_flat] += effects["dr_bonus"].to_i
      state[:esquive_flat] += effects["esquive_bonus"].to_i
      state[:attack_flat] += effects["attack_bonus"].to_i
    end

    state
  end

  # Un piège est "bien placé" si son role correspond à sa position dans la ligne
  # role front => position 0 (front line)
  # role back  => dernière position
  # role flex  => peu importe
  def position_bonus?(defense, trap_data)
    role = trap_data["role"]
    return true if role.nil? || role == "flex"

    siblings = character.fortress_defenses.where(direction: defense.direction).order(:position).pluck(:position)
    return true if siblings.empty?

    case role
    when "front" then defense.position == siblings.first
    when "back"  then defense.position == siblings.last
    else true
    end
  end

  def apply_trap_effects(traps, enemies, synergy_state)
    log = []
    return log if traps.empty?

    log << "--- Effets des défenses ---"
    if synergy_state[:active_keys].any?
      names = synergy_state[:active_keys].map { |k| GameCatalog.siege_synergies.dig(k, "name") || k }
      log << "Synergies actives : #{names.join(', ')}"
    end

    traps.each do |defense|
      trap_data = GameCatalog.siege_trap(defense.trap_key)
      next unless trap_data

      well_placed = position_bonus?(defense, trap_data)
      pos_label = well_placed && trap_data["role"] && trap_data["role"] != "flex" ? " (bien placé)" : ""

      case trap_data["type"]
      when "damage"
        base = trap_data["damage"] || 0
        bonus = well_placed ? 1 : 0
        damage = (base + bonus + synergy_state[:damage_flat]) * synergy_state[:damage_multiplier]
        damage = damage.round
        enemies.each do |e|
          e[:hp] = [e[:hp] - damage, 1].max
        end
        log << "#{trap_data['name']}#{pos_label} inflige #{damage} dégâts à chaque ennemi !"

      when "slow"
        base = trap_data["esquive_penalty"] || 0
        bonus = well_placed ? 1 : 0
        penalty = base + bonus + synergy_state[:esquive_flat]
        enemies.each do |e|
          e[:esquive][:bonus] = [e[:esquive][:bonus] - penalty, 0].max
        end
        log << "#{trap_data['name']}#{pos_label} ralentit les ennemis (-#{penalty} esquive)"

      when "weaken"
        att_base = trap_data["attack_penalty"] || 0
        dmg_base = trap_data["damage_penalty"] || 0
        bonus = well_placed ? 1 : 0
        att_penalty = att_base + bonus + synergy_state[:attack_flat]
        dmg_penalty = dmg_base + bonus
        enemies.each do |e|
          e[:attack][:bonus] = [e[:attack][:bonus] - att_penalty, 0].max
          e[:damage][:bonus] = [e[:damage][:bonus] - dmg_penalty, 0].max
        end
        log << "#{trap_data['name']}#{pos_label} affaiblit les ennemis (-#{att_penalty} attaque, -#{dmg_penalty} dégâts)"

      when "barrier"
        base = trap_data["dr_bonus"] || 0
        bonus = well_placed ? 1 : 0
        total = ((base + bonus) * synergy_state[:dr_multiplier]).round
        log << "#{trap_data['name']}#{pos_label} renforce vos défenses (+#{total} DR)"
      end
    end

    log
  end

  def finish_siege(result, combat_result, siege_data = nil)
    siege_data ||= character.siege_state || {}
    siege_week = siege_data["siege_week"] || 0
    attack_direction = siege_data["attack_direction"] || "nord"
    turns_taken = combat_result[:turn].to_i

    # Usure des défenses dans la direction attaquée, proportionnelle au nombre de tours
    wear_log = apply_defense_wear(attack_direction, turns_taken, result)

    case result
    when :victory
      character.update!(total_sieges_won: character.total_sieges_won + 1)

      SiegeLog.create!(
        character: character,
        siege_week: siege_week,
        attack_direction: attack_direction,
        result: "victory",
        xp_gained: combat_result[:rewards]&.dig(:xp) || 0,
        gold_gained: combat_result[:rewards]&.dig(:gold) || 0,
        log_data: wear_log
      )

    when :defeat
      damage_dealt = apply_building_damage(siege_week)

      SiegeLog.create!(
        character: character,
        siege_week: siege_week,
        attack_direction: attack_direction,
        result: "defeat",
        damage_dealt: damage_dealt,
        log_data: wear_log
      )
    end

    character.update!(siege_state: nil)
  end

  def apply_defense_wear(direction, turns_taken, result)
    log = []
    defenses = character.fortress_defenses.where(direction: direction).where("durability > 0")
    return log if defenses.empty?

    base_loss = wear_for_turns(turns_taken)
    # Une défaite intensifie l'usure
    loss = result == :defeat ? base_loss + 1 : base_loss
    return log if loss <= 0

    defenses.find_each do |d|
      new_dur = [d.durability - loss, 0].max
      d.update!(durability: new_dur)
      trap = GameCatalog.siege_trap(d.trap_key)
      name = trap ? trap["name"] : d.trap_key
      if new_dur.zero?
        log << "#{name} (#{direction}) est désormais cassé(e) !"
      else
        log << "#{name} (#{direction}) : -#{loss} durabilité (#{new_dur}/#{d.max_durability})"
      end
    end

    log
  end

  def wear_for_turns(turns)
    return 0 if turns <= 0

    # 1 dmg pour 1-3 tours, 2 pour 4-6, 3 pour 7-9, etc.
    ((turns - 1) / 3) + 1
  end

  def apply_building_damage(siege_week)
    damage_count = [1 + (siege_week / 12), 3].min
    targets = BUILDINGS.sample(damage_count)
    current_damage = character.building_damage.dup

    targets.each do |b|
      current_damage[b] = [(current_damage[b].to_i + 1), 2].min
    end

    character.update!(building_damage: current_damage)
    targets.index_with { |b| current_damage[b] }
  end

  def siege_info
    siege_data = character.siege_state
    return {} unless siege_data

    {
      siege: true,
      siege_week: siege_data["siege_week"],
      attack_direction: siege_data["attack_direction"],
      barrier_dr_bonus: siege_data["barrier_dr_bonus"] || 0,
      active_synergies: siege_data["active_synergies"] || []
    }
  end
end
