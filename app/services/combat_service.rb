class CombatService
  attr_reader :character, :state, :log

  def initialize(character)
    @character = character
    @state = character.combat_state&.deep_symbolize_keys
    @log = []
  end

  def start_combat(floor_number)
    enemies = MonsterFactory.build_for_floor(floor_number)
    @state = {
      floor: floor_number,
      turn: 0,
      player: build_player_state,
      enemies: enemies,
      log: ["Combat engagé à l'étage #{floor_number} !"],
      status: "active",
      player_statuses: [],
      player_debuffs: {}
    }

    enemy_names = enemies.map { |e| e[:name] }.tally.map { |n, c| c > 1 ? "#{c}x #{n}" : n }.join(", ")
    @state[:log] << "Ennemis : #{enemy_names}"

    save_state!
    combat_snapshot
  end

  def player_action(action_type, params = {})
    return { error: "Aucun combat en cours" } unless @state && @state[:status] == "active"

    @log = []
    @state[:turn] += 1
    @log << "--- Tour #{@state[:turn]} ---"

    skip = check_player_status_effects
    unless skip
      case action_type
      when "attack"
        resolve_attack(params)
      when "technique"
        resolve_technique(params[:key])
      when "magic"
        resolve_magic(params[:key])
      when "item"
        resolve_item(params[:item_id])
      else
        @log << "Action inconnue."
      end
    end

    return finish_combat(:victory) if enemies_all_dead?

    resolve_enemy_turns unless enemies_all_dead?

    return finish_combat(:defeat) if player_dead?

    tick_all_statuses
    return finish_combat(:defeat) if player_dead?

    @state[:log].concat(@log)
    save_state!
    combat_snapshot
  end

  def flee
    return { error: "Aucun combat en cours" } unless @state && @state[:status] == "active"

    escape_roll = DiceRoller.roll(character_dex_mastery, character_dex_bonus)
    difficulty = @state[:floor] / 10 + 3

    if escape_roll[:total] >= difficulty
      @state[:log] << "Fuite réussie ! (#{escape_roll[:total]} vs #{difficulty})"
      finish_combat(:fled)
    else
      @log = ["Tentative de fuite échouée ! (#{escape_roll[:total]} vs #{difficulty})"]
      resolve_enemy_turns
      if player_dead?
        @state[:log].concat(@log)
        return finish_combat(:defeat)
      end
      tick_all_statuses
      if player_dead?
        @state[:log].concat(@log)
        return finish_combat(:defeat)
      end
      @state[:log].concat(@log)
      save_state!
      combat_snapshot
    end
  end

  def combat_snapshot
    return nil unless @state

    {
      floor: @state[:floor],
      turn: @state[:turn],
      status: @state[:status],
      player: {
        hp: @state[:player][:hp],
        max_hp: @state[:player][:max_hp],
        mana: @state[:player][:mana],
        max_mana: @state[:player][:max_mana],
        statuses: @state[:player_statuses] || []
      },
      enemies: (@state[:enemies] || []).map.with_index { |e, i|
        {
          index: i,
          name: e[:name],
          hp: e[:hp],
          max_hp: e[:max_hp],
          alive: e[:hp] > 0,
          statuses: e[:statuses] || []
        }
      },
      log: @state[:log].last(20),
      recent_log: @log
    }
  end

  private

  # ═══════════════════════════════════════════
  # Player state
  # ═══════════════════════════════════════════

  def build_player_state
    {
      hp: character.current_hp,
      max_hp: character.max_hp,
      mana: character.current_mana,
      max_mana: character.max_mana
    }
  end

  def player_dead?
    @state[:player][:hp] <= 0
  end

  def enemies_all_dead?
    @state[:enemies].all? { |e| e[:hp] <= 0 }
  end

  def living_enemies
    @state[:enemies].select { |e| e[:hp] > 0 }
  end

  # ═══════════════════════════════════════════
  # Attack resolution
  # ═══════════════════════════════════════════

  def resolve_attack(params)
    target_idx = (params[:target] || 0).to_i
    target = living_enemies[target_idx] || living_enemies.first
    return @log << "Aucune cible valide." unless target

    weapon = character.equipped_weapon
    weapon_data = weapon ? GameCatalog.equipment(weapon.item_key) : nil

    acc_mastery, acc_bonus = player_accuracy(weapon_data)
    def_mastery, def_bonus = enemy_defense(target)

    hit_result = DiceRoller.opposed_roll(acc_mastery, acc_bonus, def_mastery, def_bonus)

    if hit_result[:hit]
      dmg_mastery, dmg_bonus = player_damage(weapon_data)
      res_mastery, res_bonus = enemy_resistance(target)

      dmg_roll = DiceRoller.roll(dmg_mastery, dmg_bonus)
      res_roll = DiceRoller.roll(res_mastery, res_bonus)
      final_damage = [dmg_roll[:total] - res_roll[:total], 1].max

      target[:hp] = [target[:hp] - final_damage, 0].max
      @log << "Vous attaquez #{target[:name]} : touché ! (#{hit_result[:attack][:total]} vs #{hit_result[:defense][:total]})"
      @log << "Dégâts : #{dmg_roll[:total]} - #{res_roll[:total]} résistance = #{final_damage} (#{target[:hp]}/#{target[:max_hp]} PV)"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "Vous attaquez #{target[:name]} : raté ! (#{hit_result[:attack][:total]} vs #{hit_result[:defense][:total]})"
    end
  end

  def resolve_technique(technique_key)
    tech_data = GameCatalog.technique_data(technique_key)
    unless tech_data
      @log << "Technique inconnue."
      return
    end

    has_tech = character.learned_techniques.exists?(technique_key: technique_key)
    unless has_tech
      @log << "Vous ne connaissez pas cette technique."
      return
    end

    case tech_data["type"]
    when "attack_modifier"
      resolve_modified_attack(tech_data)
    when "multi_attack"
      resolve_multi_attack(tech_data)
    when "aoe"
      resolve_aoe_attack(tech_data)
    when "armor_pierce"
      resolve_armor_pierce(tech_data)
    when "execute"
      resolve_execute(tech_data)
    when "debuff_attack"
      resolve_debuff_attack(tech_data)
    when "status_attack"
      resolve_status_attack(tech_data)
    when "counter", "combo"
      resolve_counter_stance(tech_data)
    when "stance"
      resolve_stance(tech_data)
    when "heal"
      resolve_technique_heal(tech_data)
    else
      @log << "#{tech_data["name"]} : effet non implémenté."
    end
  end

  def resolve_magic(magic_key)
    magic_data = GameCatalog.magic_data(magic_key)
    unless magic_data
      @log << "Magie inconnue."
      return
    end

    has_magic = character.learned_magics.exists?(magic_key: magic_key)
    unless has_magic
      @log << "Vous ne connaissez pas cette magie."
      return
    end

    silenced = (@state[:player_statuses] || []).any? { |s| s[:name] == "Silencé" }
    if silenced
      @log << "Vous êtes Silencé et ne pouvez pas lancer de magie !"
      return
    end

    mana_cost = magic_data["mana_cost"] || 0
    if @state[:player][:mana] < mana_cost
      @log << "Pas assez de mana (#{@state[:player][:mana]}/#{mana_cost})."
      return
    end

    @state[:player][:mana] -= mana_cost

    case magic_data["type"]
    when "damage"
      resolve_magic_damage(magic_data)
    when "damage_status"
      resolve_magic_damage(magic_data, with_status: true)
    when "damage_aoe"
      resolve_magic_aoe(magic_data)
    when "heal"
      resolve_magic_heal(magic_data)
    when "heal_cure"
      resolve_magic_heal(magic_data, cure: true)
    when "status"
      resolve_magic_status(magic_data)
    when "drain"
      resolve_magic_drain(magic_data)
    when "buff"
      resolve_magic_buff(magic_data)
    when "cure"
      resolve_magic_cure(magic_data)
    else
      @log << "#{magic_data["name"]} : effet magique non implémenté."
    end
  end

  def resolve_item(item_id)
    inv_item = character.inventory_items.find_by(id: item_id)
    unless inv_item
      @log << "Objet non trouvé."
      return
    end

    item_data = GameCatalog.item(inv_item.item_key)
    unless item_data
      @log << "Données d'objet introuvables."
      return
    end

    case item_data["effect"]
    when "heal"
      heal = DiceRoller.roll(item_data["heal_mastery"] || 1, item_data["heal_bonus"] || 0)[:total]
      @state[:player][:hp] = [@state[:player][:hp] + heal, @state[:player][:max_hp]].min
      @log << "Vous utilisez #{item_data["name"]} et récupérez #{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})."
    when "mana"
      restore = item_data["mana_restore"] || 5
      @state[:player][:mana] = [@state[:player][:mana] + restore, @state[:player][:max_mana]].min
      @log << "Vous utilisez #{item_data["name"]} et récupérez #{restore} mana."
    when "damage"
      target = living_enemies.first
      if target
        dmg = DiceRoller.roll(item_data["damage_mastery"] || 1, item_data["damage_bonus"] || 0)[:total]
        target[:hp] = [target[:hp] - dmg, 0].max
        @log << "Vous lancez #{item_data["name"]} sur #{target[:name]} : #{dmg} dégâts !"
      end
    else
      @log << "Vous utilisez #{item_data["name"]}."
    end

    if inv_item.quantity > 1
      inv_item.update!(quantity: inv_item.quantity - 1)
    else
      inv_item.destroy!
    end
  end

  # ═══════════════════════════════════════════
  # Technique sub-resolvers
  # ═══════════════════════════════════════════

  def resolve_modified_attack(tech)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    weapon_data = equipped_weapon_data
    acc_m, acc_b = player_accuracy(weapon_data)
    acc_b += (tech["accuracy_bonus"] || 0)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)

    if hit[:hit]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_b += (tech["damage_bonus"] || 0)
      dmg_m += (tech["damage_mastery_mod"] || 0)
      dmg_m = [dmg_m, 1].max
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 1].max

      target[:hp] = [target[:hp] - final, 0].max
      @log << "#{tech["name"]} sur #{target[:name]} : touché ! #{final} dégâts (#{target[:hp]}/#{target[:max_hp]} PV)"

      if tech["inflict_status"]
        chance = tech["status_chance"] || 100
        if rand(100) < chance
          apply_status_to_enemy(target, tech["inflict_status"], tech["status_duration"] || 2)
        end
      end

      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{tech["name"]} sur #{target[:name]} : raté !"
    end
  end

  def resolve_multi_attack(tech)
    hits = tech["hits"] || 2
    weapon_data = equipped_weapon_data

    hits.times do |i|
      target = living_enemies.first
      break unless target

      acc_m, acc_b = player_accuracy(weapon_data)
      acc_m += (tech["accuracy_mastery_mod"] || 0)
      acc_m = [acc_m, 1].max
      def_m, def_b = enemy_defense(target)

      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      if hit[:hit]
        dmg_m, dmg_b = player_damage(weapon_data)
        dmg_m += (tech["damage_mastery_mod"] || 0)
        dmg_m = [dmg_m, 1].max
        res_m, res_b = enemy_resistance(target)

        dmg = DiceRoller.roll(dmg_m, dmg_b)
        res = DiceRoller.roll(res_m, res_b)
        final = [dmg[:total] - res[:total], 1].max

        target[:hp] = [target[:hp] - final, 0].max
        @log << "#{tech["name"]} (frappe #{i + 1}) sur #{target[:name]} : #{final} dégâts (#{target[:hp]}/#{target[:max_hp]})"
        @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
      else
        @log << "#{tech["name"]} (frappe #{i + 1}) : raté !"
      end
    end
  end

  def resolve_aoe_attack(tech)
    weapon_data = equipped_weapon_data

    living_enemies.each do |target|
      acc_m, acc_b = player_accuracy(weapon_data)
      acc_m += (tech["accuracy_mastery_mod"] || 0)
      acc_m = [acc_m, 1].max
      def_m, def_b = enemy_defense(target)

      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      if hit[:hit]
        dmg_m, dmg_b = player_damage(weapon_data)
        dmg_m += (tech["damage_mastery_mod"] || 0)
        dmg_b += (tech["damage_bonus"] || 0)
        dmg_m = [dmg_m, 1].max
        res_m, res_b = enemy_resistance(target)

        dmg = DiceRoller.roll(dmg_m, dmg_b)
        res = DiceRoller.roll(res_m, res_b)
        final = [dmg[:total] - res[:total], 1].max

        target[:hp] = [target[:hp] - final, 0].max
        @log << "#{tech["name"]} → #{target[:name]} : #{final} dégâts (#{target[:hp]}/#{target[:max_hp]})"
        @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
      else
        @log << "#{tech["name"]} → #{target[:name]} : raté !"
      end
    end
  end

  def resolve_armor_pierce(tech)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    weapon_data = equipped_weapon_data
    acc_m, acc_b = player_accuracy(weapon_data)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit]
      dmg_m, dmg_b = player_damage(weapon_data)
      res_m, res_b = enemy_resistance(target)
      reduction_pct = tech["dr_reduction_percent"] || 50
      res_m = (res_m * (100 - reduction_pct) / 100.0).ceil
      res_b = (res_b * (100 - reduction_pct) / 100.0).ceil

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 1].max

      target[:hp] = [target[:hp] - final, 0].max
      @log << "#{tech["name"]} perce la défense de #{target[:name]} : #{final} dégâts ! (#{target[:hp]}/#{target[:max_hp]})"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{tech["name"]} : raté !"
    end
  end

  def resolve_execute(tech)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    threshold = tech["hp_threshold"] || 25
    low_hp = target[:hp] <= (target[:max_hp] * threshold / 100.0)

    weapon_data = equipped_weapon_data
    acc_m, acc_b = player_accuracy(weapon_data)
    acc_b += (tech["accuracy_bonus"] || 0)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit]
      dmg_m, dmg_b = player_damage(weapon_data)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 1].max
      final *= (tech["damage_multiplier"] || 2) if low_hp

      target[:hp] = [target[:hp] - final, 0].max
      bonus_text = low_hp ? " (EXÉCUTION !)" : ""
      @log << "#{tech["name"]} sur #{target[:name]}#{bonus_text} : #{final} dégâts (#{target[:hp]}/#{target[:max_hp]})"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{tech["name"]} : raté !"
    end
  end

  def resolve_debuff_attack(tech)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    weapon_data = equipped_weapon_data
    acc_m, acc_b = player_accuracy(weapon_data)
    acc_b += (tech["accuracy_bonus"] || 0)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_b += (tech["damage_bonus"] || 0)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 0].max

      target[:hp] = [target[:hp] - final, 0].max

      debuff_type = tech["debuff"]
      debuff_val = tech["debuff_value"] || 1
      target[:debuffs] ||= {}
      target[:debuffs][debuff_type] = (target[:debuffs][debuff_type] || 0) + debuff_val

      @log << "#{tech["name"]} : #{final} dégâts + #{debuff_type} (#{target[:name]})"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{tech["name"]} : raté !"
    end
  end

  def resolve_status_attack(tech)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    weapon_data = equipped_weapon_data
    acc_m, acc_b = player_accuracy(weapon_data)
    acc_b += (tech["accuracy_bonus"] || 0)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_b += (tech["damage_bonus"] || 0)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 0].max

      target[:hp] = [target[:hp] - final, 0].max
      apply_status_to_enemy(target, tech["inflict_status"], tech["status_duration"] || 2)
      @log << "#{tech["name"]} : #{final} dégâts + #{tech["inflict_status"]} sur #{target[:name]} (#{target[:hp]}/#{target[:max_hp]})"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{tech["name"]} : raté !"
    end
  end

  def resolve_counter_stance(tech)
    @state[:player_counter] = {
      parade_bonus: tech["parade_bonus"] || 0,
      esquive_bonus: tech["esquive_bonus"] || 0,
      counter_on_success: tech["counter_on_success"] || false,
      counter_damage_bonus: tech["counter_damage_bonus"] || 0
    }
    @log << "#{tech["name"]} : posture de contre-attaque activée."
  end

  def resolve_stance(tech)
    esquive_bonus = tech["esquive_bonus"] || 0
    parade_bonus = tech["parade_bonus"] || 0
    dr_bonus = tech["dr_bonus"] || 0
    @state[:player_stance] = { esquive_bonus: esquive_bonus, parade_bonus: parade_bonus, dr_bonus: dr_bonus }
    @log << "#{tech["name"]} : posture défensive (+#{esquive_bonus} esquive, +#{parade_bonus} parade, +#{dr_bonus} DR)."
  end

  def resolve_technique_heal(tech)
    heal_m = tech["heal_mastery"] || 1
    heal_b = tech["heal_bonus"] || 0
    heal = DiceRoller.roll(heal_m, heal_b)[:total]
    @state[:player][:hp] = [@state[:player][:hp] + heal, @state[:player][:max_hp]].min
    @log << "#{tech["name"]} : vous récupérez #{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})."
  end

  # ═══════════════════════════════════════════
  # Magic sub-resolvers
  # ═══════════════════════════════════════════

  def resolve_magic_damage(magic, with_status: false)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    element = magic["element"]
    skill = find_player_skill_for_element(element)
    acc_m = skill ? skill.mastery : character.intelligence
    acc_b = skill ? skill.bonus : 0

    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit]
      dmg = DiceRoller.roll(magic["damage_mastery"] || 1, magic["damage_bonus"] || 0)
      target[:hp] = [target[:hp] - dmg[:total], 0].max
      @log << "#{magic["name"]} sur #{target[:name]} : #{dmg[:total]} dégâts ! (#{target[:hp]}/#{target[:max_hp]})"

      if with_status && magic["inflict_status"]
        chance = magic["status_chance"] || 50
        if rand(100) < chance
          apply_status_to_enemy(target, magic["inflict_status"], magic["status_duration"] || 2)
        end
      end

      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{magic["name"]} sur #{target[:name]} : raté !"
    end
  end

  def resolve_magic_aoe(magic)
    element = magic["element"]
    skill = find_player_skill_for_element(element)
    acc_m = skill ? skill.mastery : character.intelligence
    acc_b = skill ? skill.bonus : 0

    living_enemies.each do |target|
      def_m, def_b = enemy_defense(target)
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)

      if hit[:hit]
        dmg = DiceRoller.roll(magic["damage_mastery"] || 1, magic["damage_bonus"] || 0)
        target[:hp] = [target[:hp] - dmg[:total], 0].max
        @log << "#{magic["name"]} → #{target[:name]} : #{dmg[:total]} dégâts (#{target[:hp]}/#{target[:max_hp]})"

        if magic["inflict_status"]
          chance = magic["status_chance"] || 50
          if rand(100) < chance
            apply_status_to_enemy(target, magic["inflict_status"], magic["status_duration"] || 2)
          end
        end

        @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
      else
        @log << "#{magic["name"]} → #{target[:name]} : raté !"
      end
    end
  end

  def resolve_magic_heal(magic, cure: false)
    heal_m = magic["heal_mastery"] || 1
    heal_b = magic["heal_bonus"] || 0
    heal = DiceRoller.roll(heal_m, heal_b)[:total]
    @state[:player][:hp] = [@state[:player][:hp] + heal, @state[:player][:max_hp]].min
    @log << "#{magic["name"]} : +#{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"

    if cure
      removed = (@state[:player_statuses] || []).select { |s| status_is_negative?(s[:name]) }.map { |s| s[:name] }
      @state[:player_statuses]&.reject! { |s| status_is_negative?(s[:name]) }
      @log << "Statuts négatifs retirés : #{removed.join(", ")}" if removed.any?
    end
  end

  def resolve_magic_status(magic)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    if magic["damage_mastery"] && magic["damage_mastery"] > 0
      dmg = DiceRoller.roll(magic["damage_mastery"], magic["damage_bonus"] || 0)
      target[:hp] = [target[:hp] - dmg[:total], 0].max
      @log << "#{magic["name"]} inflige #{dmg[:total]} dégâts à #{target[:name]}."
    end

    apply_status_to_enemy(target, magic["inflict_status"], magic["status_duration"] || 2)
    @log << "#{target[:name]} est #{magic["inflict_status"]} !"
    @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
  end

  def resolve_magic_drain(magic)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    element = magic["element"]
    skill = find_player_skill_for_element(element)
    acc_m = skill ? skill.mastery : character.intelligence
    acc_b = skill ? skill.bonus : 0
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit]
      dmg = DiceRoller.roll(magic["damage_mastery"] || 1, magic["damage_bonus"] || 0)
      target[:hp] = [target[:hp] - dmg[:total], 0].max
      drain_pct = magic["drain_percent"] || 50
      healed = (dmg[:total] * drain_pct / 100.0).ceil
      @state[:player][:hp] = [@state[:player][:hp] + healed, @state[:player][:max_hp]].min

      @log << "#{magic["name"]} : #{dmg[:total]} dégâts, +#{healed} PV drainés (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{magic["name"]} : raté !"
    end
  end

  def resolve_magic_buff(magic)
    buff_name = magic["buff_status"]
    buff_duration = magic["buff_duration"] || 2
    apply_status_to_player(buff_name, buff_duration)
    @log << "#{magic["name"]} : #{buff_name} pendant #{buff_duration} tours."

    if magic["heal_mastery"]
      heal = DiceRoller.roll(magic["heal_mastery"], magic["heal_bonus"] || 0)[:total]
      @state[:player][:hp] = [@state[:player][:hp] + heal, @state[:player][:max_hp]].min
      @log << "Et +#{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"
    end
  end

  def resolve_magic_cure(magic)
    removed = (@state[:player_statuses] || []).select { |s| status_is_negative?(s[:name]) }.map { |s| s[:name] }
    @state[:player_statuses]&.reject! { |s| status_is_negative?(s[:name]) }
    @log << "#{magic["name"]} : statuts négatifs retirés (#{removed.join(", ")})" if removed.any?
    @log << "#{magic["name"]} : aucun statut négatif à retirer." if removed.empty?
  end

  # ═══════════════════════════════════════════
  # Enemy turn resolution
  # ═══════════════════════════════════════════

  def resolve_enemy_turns
    living_enemies.each do |enemy|
      next if enemy_is_stunned?(enemy)
      next if enemy_is_paralyzed?(enemy)

      if enemy[:abilities]&.any? && rand(100) < 30
        resolve_enemy_ability(enemy)
      else
        resolve_enemy_attack(enemy)
      end
    end

    @state[:player_counter] = nil
    @state[:player_stance] = nil
  end

  def resolve_enemy_attack(enemy)
    att_m = enemy[:attack][:mastery]
    att_b = enemy[:attack][:bonus]
    apply_enemy_status_mods_attack(enemy, att_m, att_b) => { mastery: att_m, bonus: att_b }

    def_m, def_b = player_defense_vs(enemy)

    hit = DiceRoller.opposed_roll(att_m, att_b, def_m, def_b)
    if hit[:hit]
      counter = @state[:player_counter]
      if counter && counter[:counter_on_success]
        @log << "#{enemy[:name]} vous attaque mais vous contre-attaquez !"
        resolve_player_counter_hit(enemy, counter)
        return
      end

      dmg_m = enemy[:damage][:mastery]
      dmg_b = enemy[:damage][:bonus]
      res_m = character.vigueur
      res_b = character.total_dr_bonus
      stance_dr = @state.dig(:player_stance, :dr_bonus) || 0

      protected_status = (@state[:player_statuses] || []).find { |s| s[:name] == "Protégé" }
      extra_dr_m = protected_status ? 1 : 0

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m + character.total_dr_mastery + extra_dr_m, res_b + stance_dr)
      final = [dmg[:total] - res[:total], 1].max

      @state[:player][:hp] -= final
      @log << "#{enemy[:name]} vous attaque : #{final} dégâts ! (#{@state[:player][:hp]}/#{@state[:player][:max_hp]} PV)"
      @log << "Vous êtes tombé au combat !" if @state[:player][:hp] <= 0
    else
      @log << "#{enemy[:name]} vous attaque : raté !"

      counter = @state[:player_counter]
      if counter && counter[:counter_on_success]
        @log << "Contre-attaque !"
        resolve_player_counter_hit(enemy, counter)
      end
    end
  end

  def resolve_enemy_ability(enemy)
    ability_key = enemy[:abilities].sample
    ability = GameCatalog.technique_data(ability_key) || GameCatalog.magic_data(ability_key)

    unless ability
      resolve_enemy_attack(enemy)
      return
    end

    if ability["mana_cost"]
      resolve_enemy_magic_ability(enemy, ability)
    else
      resolve_enemy_technique_ability(enemy, ability)
    end
  end

  def resolve_enemy_technique_ability(enemy, tech)
    att_m = enemy[:attack][:mastery]
    att_b = enemy[:attack][:bonus] + (tech["accuracy_bonus"] || 0)
    def_m, def_b = player_defense_vs(enemy)

    hit = DiceRoller.opposed_roll(att_m, att_b, def_m, def_b)
    if hit[:hit]
      dmg_m = enemy[:damage][:mastery] + (tech["damage_mastery_mod"] || 0)
      dmg_m = [dmg_m, 1].max
      dmg_b = enemy[:damage][:bonus] + (tech["damage_bonus"] || 0)
      res_m = character.vigueur + character.total_dr_mastery
      res_b = character.total_dr_bonus

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 1].max

      @state[:player][:hp] -= final
      @log << "#{enemy[:name]} utilise #{tech["name"]} : #{final} dégâts !"

      if tech["inflict_status"]
        chance = tech["status_chance"] || 100
        if rand(100) < chance
          apply_status_to_player(tech["inflict_status"], tech["status_duration"] || 2)
          @log << "Vous êtes #{tech["inflict_status"]} !"
        end
      end
    else
      @log << "#{enemy[:name]} utilise #{tech["name"]} : raté !"
    end
  end

  def resolve_enemy_magic_ability(enemy, magic)
    acc_m = enemy[:attack][:mastery]
    acc_b = enemy[:attack][:bonus]
    def_m, def_b = player_defense_vs(enemy)

    case magic["type"]
    when "heal"
      heal = DiceRoller.roll(magic["heal_mastery"] || 1, magic["heal_bonus"] || 0)[:total]
      enemy[:hp] = [enemy[:hp] + heal, enemy[:max_hp]].min
      @log << "#{enemy[:name]} lance #{magic["name"]} et récupère #{heal} PV (#{enemy[:hp]}/#{enemy[:max_hp]})"
      return
    when "damage", "damage_status"
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      if hit[:hit]
        dmg = DiceRoller.roll(magic["damage_mastery"] || 1, magic["damage_bonus"] || 0)[:total]
        @state[:player][:hp] -= dmg
        @log << "#{enemy[:name]} lance #{magic["name"]} : #{dmg} dégâts !"

        if magic["inflict_status"]
          chance = magic["status_chance"] || 50
          if rand(100) < chance
            apply_status_to_player(magic["inflict_status"], magic["status_duration"] || 2)
            @log << "Vous êtes #{magic["inflict_status"]} !"
          end
        end
      else
        @log << "#{enemy[:name]} lance #{magic["name"]} : raté !"
      end
    when "drain"
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      if hit[:hit]
        dmg = DiceRoller.roll(magic["damage_mastery"] || 1, magic["damage_bonus"] || 0)[:total]
        @state[:player][:hp] -= dmg
        healed = (dmg * (magic["drain_percent"] || 50) / 100.0).ceil
        enemy[:hp] = [enemy[:hp] + healed, enemy[:max_hp]].min
        @log << "#{enemy[:name]} lance #{magic["name"]} : #{dmg} dégâts, +#{healed} PV drainés"
      else
        @log << "#{enemy[:name]} lance #{magic["name"]} : raté !"
      end
    else
      resolve_enemy_attack(enemy)
    end
  end

  def resolve_player_counter_hit(enemy, counter)
    weapon_data = equipped_weapon_data
    dmg_m, dmg_b = player_damage(weapon_data)
    dmg_b += (counter[:counter_damage_bonus] || 0)
    res_m, res_b = enemy_resistance(enemy)

    dmg = DiceRoller.roll(dmg_m, dmg_b)
    res = DiceRoller.roll(res_m, res_b)
    final = [dmg[:total] - res[:total], 1].max

    enemy[:hp] = [enemy[:hp] - final, 0].max
    @log << "Contre-attaque ! #{final} dégâts à #{enemy[:name]} (#{enemy[:hp]}/#{enemy[:max_hp]})"
    @log << "#{enemy[:name]} est vaincu !" if enemy[:hp] <= 0
  end

  # ═══════════════════════════════════════════
  # Status effects
  # ═══════════════════════════════════════════

  def check_player_status_effects
    skip = false
    confused = false

    (@state[:player_statuses] || []).each do |s|
      case s[:name]
      when "Étourdi"
        @log << "Vous êtes étourdi et perdez votre tour !"
        skip = true
      when "Paralysé"
        if rand(100) < 50
          @log << "Vous êtes paralysé et ne pouvez pas agir !"
          skip = true
        end
      when "Confus"
        if rand(100) < 25
          dmg = DiceRoller.roll(1, 0)[:total]
          @state[:player][:hp] -= dmg
          @log << "Confus, vous vous frappez vous-même ! #{dmg} dégâts."
          confused = true
        end
      end
    end

    skip || confused
  end

  def tick_all_statuses
    tick_player_statuses
    @state[:enemies].each { |e| tick_enemy_statuses(e) if e[:hp] > 0 }
  end

  def tick_player_statuses
    @state[:player_statuses] ||= []
    @state[:player_statuses].each do |s|
      status_data = GameCatalog.all_statuses_data[s[:name]]
      next unless status_data

      if status_data["tick_damage_mastery"]
        dmg = DiceRoller.roll(status_data["tick_damage_mastery"], status_data["tick_damage_bonus"] || 0)[:total]
        @state[:player][:hp] -= dmg
        @log << "#{s[:name]} : vous subissez #{dmg} dégâts (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"
      end

      if status_data["tick_heal_mastery"]
        heal = DiceRoller.roll(status_data["tick_heal_mastery"], status_data["tick_heal_bonus"] || 0)[:total]
        @state[:player][:hp] = [@state[:player][:hp] + heal, @state[:player][:max_hp]].min
        @log << "#{s[:name]} : +#{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"
      end

      s[:remaining] -= 1
    end
    @state[:player_statuses].reject! { |s| s[:remaining] <= 0 }
  end

  def tick_enemy_statuses(enemy)
    enemy[:statuses] ||= []
    enemy[:statuses].each do |s|
      status_data = GameCatalog.all_statuses_data[s[:name]]
      next unless status_data

      if status_data["tick_damage_mastery"]
        dmg = DiceRoller.roll(status_data["tick_damage_mastery"], status_data["tick_damage_bonus"] || 0)[:total]
        enemy[:hp] = [enemy[:hp] - dmg, 0].max
        @log << "#{s[:name]} : #{enemy[:name]} subit #{dmg} dégâts (#{enemy[:hp]}/#{enemy[:max_hp]})"
        @log << "#{enemy[:name]} est vaincu !" if enemy[:hp] <= 0
      end

      s[:remaining] -= 1
    end
    enemy[:statuses].reject! { |s| s[:remaining] <= 0 }
  end

  def apply_status_to_enemy(enemy, status_name, duration)
    enemy[:statuses] ||= []
    existing = enemy[:statuses].find { |s| s[:name] == status_name }
    if existing
      existing[:remaining] = [existing[:remaining], duration].max
    else
      enemy[:statuses] << { name: status_name, remaining: duration }
    end
  end

  def apply_status_to_player(status_name, duration)
    @state[:player_statuses] ||= []
    existing = @state[:player_statuses].find { |s| s[:name] == status_name }
    if existing
      existing[:remaining] = [existing[:remaining], duration].max
    else
      @state[:player_statuses] << { name: status_name, remaining: duration }
    end
  end

  def enemy_is_stunned?(enemy)
    stunned = (enemy[:statuses] || []).any? { |s| s[:name] == "Étourdi" }
    if stunned
      @log << "#{enemy[:name]} est étourdi et perd son tour !"
    end
    stunned
  end

  def enemy_is_paralyzed?(enemy)
    paralyzed = (enemy[:statuses] || []).any? { |s| s[:name] == "Paralysé" }
    if paralyzed && rand(100) < 50
      @log << "#{enemy[:name]} est paralysé et ne peut pas agir !"
      return true
    end
    false
  end

  def status_is_negative?(name)
    data = GameCatalog.all_statuses_data[name]
    data && data["type"] == "negative"
  end

  # ═══════════════════════════════════════════
  # Stat helpers
  # ═══════════════════════════════════════════

  def player_accuracy(weapon_data)
    if weapon_data
      skill_name = weapon_skill_name(weapon_data)
      skill = character.skills.find_by(name: skill_name)
      mastery = skill ? skill.mastery : character.dexterite
      bonus = (skill ? skill.bonus : 0) + (weapon_data["accuracy_bonus"] || 0)
    else
      mastery = character.dexterite
      bonus = 0
    end

    apply_player_accuracy_mods(mastery, bonus)
  end

  def player_damage(weapon_data)
    if weapon_data
      is_ranged = weapon_data["category"] == "arme_a_distance"
      stat = is_ranged ? character.dexterite : character.vigueur
      mastery = stat
      bonus = (weapon_data["damage_mastery"] || 0) + (weapon_data["damage_bonus"] || 0)
    else
      mastery = character.vigueur
      bonus = 0
    end

    apply_player_damage_mods(mastery, bonus)
  end

  def enemy_defense(enemy)
    esquive_m = enemy[:esquive][:mastery]
    esquive_b = enemy[:esquive][:bonus]

    debuffs = enemy[:debuffs] || {}
    if debuffs["parade_reduction"]
      esquive_b = [esquive_b - debuffs["parade_reduction"], 0].max
    end

    [esquive_m, esquive_b]
  end

  def enemy_resistance(enemy)
    vig_m = enemy[:vigueur][:mastery]
    vig_b = enemy[:vigueur][:bonus]
    dr_m = enemy[:dr][:mastery]
    dr_b = enemy[:dr][:bonus]
    [vig_m + dr_m, vig_b + dr_b]
  end

  def player_defense_vs(_enemy)
    esquive = character.skills.find_by(name: "Esquive")
    mastery = esquive ? esquive.mastery : character.dexterite
    bonus = esquive ? esquive.bonus : 0

    stance = @state[:player_stance]
    if stance
      mastery += (stance[:esquive_bonus] || 0)
      bonus += (stance[:parade_bonus] || 0)
    end

    counter = @state[:player_counter]
    if counter
      mastery += (counter[:esquive_bonus] || 0)
      bonus += (counter[:parade_bonus] || 0)
    end

    accel = (@state[:player_statuses] || []).find { |s| s[:name] == "Accéléré" }
    bonus += 1 if accel

    [mastery, bonus]
  end

  def apply_player_accuracy_mods(mastery, bonus)
    (@state[:player_statuses] || []).each do |s|
      data = GameCatalog.all_statuses_data[s[:name]]
      next unless data
      mastery -= (data["accuracy_mastery_penalty"] || 0)
      mastery += (data["accuracy_mastery_bonus"] || 0)
      mastery -= (data["mastery_penalty"] || 0)
      bonus += (data["bonus_all"] || 0)
      bonus -= (data["bonus_penalty"] || 0)
    end

    invisible = (@state[:player_statuses] || []).find { |s| s[:name] == "Invisible" }
    if invisible
      @state[:player_statuses].delete(invisible)
      return [99, 0]
    end

    [[mastery, 1].max, bonus]
  end

  def apply_player_damage_mods(mastery, bonus)
    (@state[:player_statuses] || []).each do |s|
      data = GameCatalog.all_statuses_data[s[:name]]
      next unless data
      mastery += (data["damage_mastery_bonus"] || 0)
      mastery -= (data["damage_mastery_penalty"] || 0)
      mastery -= (data["mastery_penalty"] || 0)
      bonus += (data["bonus_all"] || 0)
      bonus -= (data["bonus_penalty"] || 0)
    end
    [[mastery, 1].max, bonus]
  end

  def apply_enemy_status_mods_attack(enemy, att_m, att_b)
    (enemy[:statuses] || []).each do |s|
      data = GameCatalog.all_statuses_data[s[:name]]
      next unless data
      att_m -= (data["mastery_penalty"] || 0)
      att_m -= (data["accuracy_mastery_penalty"] || 0)
      att_b -= (data["bonus_penalty"] || 0)
    end

    debuffs = enemy[:debuffs] || {}
    att_m -= (debuffs["attack_reduction"] || 0)

    { mastery: [att_m, 1].max, bonus: att_b }
  end

  def weapon_skill_name(weapon_data)
    case weapon_data["category"]
    when "arme_a_distance" then "Arc"
    when "arme_de_melee"
      if weapon_data["two_handed"]
        "Arme à deux mains"
      else
        "Arme à une main"
      end
    else
      "Arme à une main"
    end
  end

  def equipped_weapon_data
    weapon = character.equipped_weapon
    weapon ? GameCatalog.equipment(weapon.item_key) : nil
  end

  def find_player_skill_for_element(element)
    name = case element
           when "feu" then "Feu"
           when "eau" then "Eau"
           when "ombre" then "Ombre"
           when "lumiere" then "Lumière"
           when "nature" then "Nature"
           end
    character.skills.find_by(name: name)
  end

  def character_dex_mastery
    character.dexterite
  end

  def character_dex_bonus
    skill = character.skills.find_by(name: "Esquive")
    skill ? skill.bonus : 0
  end

  # ═══════════════════════════════════════════
  # Combat end
  # ═══════════════════════════════════════════

  def finish_combat(result)
    @state[:status] = result.to_s
    rewards = {}

    case result
    when :victory
      xp_reward = @state[:floor] * 3 + 5
      gold_reward = @state[:floor] * 2 + rand(1..[@state[:floor], 1].max)
      character.update!(
        xp: character.xp + xp_reward,
        gold: character.gold + gold_reward,
        current_hp: [@state[:player][:hp], 1].max,
        current_mana: @state[:player][:mana],
        current_floor: [@state[:floor], character.current_floor].max,
        combat_state: nil
      )
      character.advance_day

      @state[:log].concat(@log)
      @state[:log] << "Victoire ! +#{xp_reward} XP, +#{gold_reward} or."
      rewards = { xp: xp_reward, gold: gold_reward }

      CombatLog.create!(character: character, floor: @state[:floor], result: "victory",
                         xp_gained: xp_reward, gold_gained: gold_reward,
                         log_data: @state[:log].last(50))
    when :defeat
      character.update!(
        current_hp: 1,
        current_mana: [(@state[:player][:mana] || 0), 0].max,
        combat_state: nil
      )

      @state[:log].concat(@log)
      @state[:log] << "Défaite... Vous revenez en ville avec 1 PV."

      CombatLog.create!(character: character, floor: @state[:floor], result: "defeat",
                         log_data: @state[:log].last(50))
    when :fled
      character.update!(
        current_hp: [@state[:player][:hp], 1].max,
        current_mana: [@state[:player][:mana], 0].max,
        combat_state: nil
      )
      character.advance_day

      @state[:log].concat(@log) if @log.any?

      CombatLog.create!(character: character, floor: @state[:floor], result: "fled",
                         log_data: @state[:log].last(50))
    end

    {
      floor: @state[:floor],
      turn: @state[:turn],
      status: @state[:status],
      player: {
        hp: character.current_hp,
        max_hp: character.max_hp,
        mana: character.current_mana,
        max_mana: character.max_mana,
        statuses: []
      },
      enemies: (@state[:enemies] || []).map.with_index { |e, i|
        { index: i, name: e[:name], hp: e[:hp], max_hp: e[:max_hp], alive: e[:hp] > 0, statuses: e[:statuses] || [] }
      },
      log: @state[:log].last(20),
      recent_log: @state[:log].last(10),
      rewards: rewards
    }
  end

  def save_state!
    character.update!(combat_state: @state.deep_stringify_keys)
  end
end
