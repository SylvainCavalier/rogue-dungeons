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

    # Appliquer les effets des pièges
    traps = character.fortress_defenses.where(direction: attack_direction)
    trap_log = apply_trap_effects(traps, enemies)

    # Calculer les bonus DR des pièges de type barrier
    barrier_dr_bonus = traps.sum do |d|
      trap_data = GameCatalog.siege_trap(d.trap_key)
      trap_data && trap_data["type"] == "barrier" ? (trap_data["dr_bonus"] || 0) : 0
    end

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
        "barrier_dr_bonus" => barrier_dr_bonus
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

  def apply_trap_effects(traps, enemies)
    log = []
    return log if traps.empty?

    log << "--- Effets des défenses ---"

    traps.each do |defense|
      trap_data = GameCatalog.siege_trap(defense.trap_key)
      next unless trap_data

      case trap_data["type"]
      when "damage"
        damage = trap_data["damage"] || 0
        enemies.each do |e|
          e[:hp] = [e[:hp] - damage, 1].max
        end
        log << "#{trap_data["name"]} inflige #{damage} dégâts à chaque ennemi !"

      when "slow"
        penalty = trap_data["esquive_penalty"] || 0
        enemies.each do |e|
          e[:esquive][:bonus] = [e[:esquive][:bonus] - penalty, 0].max
        end
        log << "#{trap_data["name"]} ralentit les ennemis (-#{penalty} esquive)"

      when "weaken"
        att_penalty = trap_data["attack_penalty"] || 0
        dmg_penalty = trap_data["damage_penalty"] || 0
        enemies.each do |e|
          e[:attack][:bonus] = [e[:attack][:bonus] - att_penalty, 0].max
          e[:damage][:bonus] = [e[:damage][:bonus] - dmg_penalty, 0].max
        end
        log << "#{trap_data["name"]} affaiblit les ennemis (-#{att_penalty} attaque, -#{dmg_penalty} dégâts)"

      when "barrier"
        log << "#{trap_data["name"]} renforce vos défenses (+#{trap_data["dr_bonus"] || 0} DR)"
      end
    end

    log
  end

  def finish_siege(result, combat_result, siege_data = nil)
    siege_data ||= character.siege_state || {}
    siege_week = siege_data["siege_week"] || 0
    attack_direction = siege_data["attack_direction"] || "nord"
    damage_dealt = {}

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
        log_data: []
      )

    when :defeat
      damage_dealt = apply_building_damage(siege_week)

      SiegeLog.create!(
        character: character,
        siege_week: siege_week,
        attack_direction: attack_direction,
        result: "defeat",
        damage_dealt: damage_dealt,
        log_data: []
      )
    end

    character.update!(siege_state: nil)
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
      barrier_dr_bonus: siege_data["barrier_dr_bonus"] || 0
    }
  end
end
