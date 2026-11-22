class CombatService
  COMBAT_ITEM_EFFECTS = %w[heal restore_mana cure_status damage combat_buff enemy_status escape].freeze
  # Item effects that only make sense in a fight (refused, not consumed, outside of one).
  COMBAT_ONLY_ITEM_EFFECTS = %w[damage combat_buff enemy_status escape].freeze

  # Parry is easier to succeed than a dodge, but a successful parry still lets
  # PARRY_CHIP_DAMAGE through. A successful dodge avoids everything.
  PARRY_ROLL_BONUS = 2
  PARRY_CHIP_DAMAGE = 1

  # % chance per turn that an enemy uses one of its abilities (monster
  # `ability_chance` overrides it: casters rely on their spells).
  DEFAULT_ABILITY_CHANCE = 30

  # Statuses the player can shake off with a Sang-Froid roll (vs the enemy's attack roll).
  MENTAL_STATUSES = %w[Étourdi Paralysé Terrorisé Confus Aveuglé].freeze
  # Failing the Sang-Froid roll by at most this much shortens the status by 1 round.
  SANG_FROID_PARTIAL_MARGIN = 2

  # Defense mode + dice shown by the combat toggle.
  def self.defense_info(character)
    esq_m, esq_b = character.defense_roll("esquive")
    par_m, par_b = character.defense_roll("parade")
    {
      mode: character.effective_defense_mode,
      can_parry: character.can_parry?,
      esquive: DiceRoller.notation(esq_m, esq_b),
      parade: DiceRoller.notation(par_m, par_b + PARRY_ROLL_BONUS)
    }
  end

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

    begin_combat!
  end

  # Rolls initiative once for the whole fight, then lets the enemies faster
  # than the player act before the player's first turn. Also called by
  # SiegeService once it has built the siege combat state.
  def begin_combat!
    @log = []
    roll_initiative!
    @state[:turn] = 1
    start_round_log!
    end_turn_with do
      if faster_enemies.any? && (compass = character.passive_item("no_ambush"))
        @log << "#{compass['name']} : vous évitez l'embuscade, les ennemis plus rapides n'agissent pas avant vous."
      else
        resolve_enemy_turns(faster_enemies)
      end
    end
  end

  def player_action(action_type, params = {})
    return { error: "Aucun combat en cours" } unless @state && @state[:status] == "active"

    if action_type == "technique" && (unavailable = technique_unavailable(params[:key]))
      return { error: unavailable }
    end
    if action_type == "magic" && GameCatalog.magic_data(params[:key].to_s)&.dig("type") == "raise_dead" && raisable_corpse.nil?
      return { error: "Aucun ennemi tombé à relever (les boss ne peuvent pas l'être)" }
    end

    @log = []
    resume_legacy_combat!
    # A stance/counter covers the enemy actions until the player's next action.
    @state[:player_counter] = nil
    @state[:player_stance] = nil
    @used_technique = nil

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
        return finish_combat(:fled) if @escaped
      when "analyze"
        resolve_analyze(params)
      else
        @log << "Action inconnue."
      end
    end

    tick_technique_cooldowns!(except: @used_technique)
    resolve_ally_turns
    tick_player_statuses
    close_round
  end

  def flee
    return { error: "Aucun combat en cours" } unless @state && @state[:status] == "active"

    @log = []
    resume_legacy_combat!
    @state[:player_counter] = nil
    @state[:player_stance] = nil
    tick_technique_cooldowns!

    escape_roll = DiceRoller.roll(character_dex_mastery, character_dex_bonus)
    difficulty = @state[:floor] / 10 + 3

    if escape_roll[:total] >= difficulty
      @log << "Fuite réussie ! (#{escape_roll[:total]} vs #{difficulty})"
      finish_combat(:fled)
    else
      @log << "Tentative de fuite échouée ! (#{escape_roll[:total]} vs #{difficulty})"
      resolve_ally_turns
      tick_player_statuses
      close_round
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
        statuses: @state[:player_statuses] || [],
        defense: self.class.defense_info(character),
        initiative: @state[:player_initiative],
        technique_cooldowns: (@state[:technique_cooldowns] || {}).select { |_, v| v.to_i.positive? }.transform_keys(&:to_s)
      },
      allies: (@state[:allies] || []).map { |a|
        { key: a[:key], name: a[:name], hp: a[:hp], max_hp: a[:max_hp], alive: a[:hp] > 0,
          taunt: a[:taunt], role: a[:role], reborn: a[:reborn] || false,
          undead: a[:undead] || false, image_dir: a[:image_dir] || "summons" }
      },
      enemies: (@state[:enemies] || []).map.with_index { |e, i|
        {
          index: i,
          key: e[:key],
          name: e[:name],
          hp: e[:hp],
          max_hp: e[:max_hp],
          alive: e[:hp] > 0,
          statuses: e[:statuses] || [],
          initiative: e[:initiative],
          faster: faster_than_player?(e),
          intent: e[:intent_known] ? intent_label(e[:intent]) : nil,
          revealed_resistances: revealed_resistances_for(e)
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
  # Monster knowledge / Analyze
  # ═══════════════════════════════════════════

  def monster_knowledge_for(monster_key)
    return nil unless monster_key
    @monster_knowledges_cache ||= {}
    @monster_knowledges_cache[monster_key] ||=
      character.monster_knowledges.find_or_initialize_by(monster_key: monster_key)
  end

  def revealed_resistances_for(enemy)
    return {} if enemy[:key].blank?
    resistances = (enemy[:resistances] || {}).transform_keys(&:to_s)
    return {} if resistances.empty?

    knowledge = monster_knowledge_for(enemy[:key])
    return {} unless knowledge
    resistances.select { |k, _| knowledge.revealed?(k) }
  end

  def resolve_analyze(params)
    target_idx = (params[:target] || 0).to_i
    target = living_enemies[target_idx] || living_enemies.first
    return @log << "Aucune cible à analyser." unless target

    if target[:key].blank? || (target[:resistances] || {}).empty?
      @log << "#{target[:name]} ne semble avoir aucune résistance notable."
      return
    end

    skill = character.skills.find_by(name: "Observation")
    obs_m = skill ? skill.mastery : character.perception
    obs_b = skill ? skill.bonus : 0

    dc = 8 + (@state[:floor].to_i / 5)
    roll = DiceRoller.roll(obs_m, obs_b)
    notation = DiceRoller.notation(obs_m, obs_b)

    knowledge = monster_knowledge_for(target[:key])
    present_keys = target[:resistances].keys.map(&:to_s)
    unknown_keys = present_keys - knowledge.revealed_keys

    if unknown_keys.empty?
      @log << "Observation (#{notation}) : vous connaissez déjà toutes les résistances de #{target[:name]}."
      return
    end

    if roll[:total] < dc
      @log << "Observation (#{notation}) : #{roll[:total]} vs DC #{dc} — vous n'apprenez rien sur #{target[:name]}."
      return
    end

    margin = roll[:total] - dc
    if margin >= 10
      knowledge.reveal!(unknown_keys)
      @log << "Observation (#{notation}) : #{roll[:total]} vs DC #{dc} — analyse complète ! Toutes les résistances de #{target[:name]} sont percées à jour."
    else
      reveal_count = margin >= 5 ? [2, unknown_keys.size].min : 1
      revealed = unknown_keys.sample(reveal_count)
      knowledge.reveal!(revealed)
      labels = revealed.map { |k| ELEMENT_LABELS[k] || k }.join(", ")
      @log << "Observation (#{notation}) : #{roll[:total]} vs DC #{dc} — vous décelez la #{revealed.size > 1 ? "résistance" : "résistance"} #{labels} de #{target[:name]}."
    end
  end

  # ═══════════════════════════════════════════
  # Attack resolution
  # ═══════════════════════════════════════════

  def resolve_attack(params)
    target_idx = (params[:target] || 0).to_i
    target = living_enemies[target_idx] || living_enemies.first
    return @log << "Aucune cible valide." unless target

    weapon_data = equipped_weapon_data
    pierced = pierced_targets(target, weapon_data)
    @log << "Votre arme transperce #{pierced.map { |e| e[:name] }.join(" et ")} !" if pierced.size > 1
    pierced.each { |enemy| resolve_attack_on(enemy, weapon_data) }
  end

  # Piercing weapons (`pierce_targets` in the catalog, e.g. spears) also hit the
  # next living enemies after the chosen target (wrapping around), one roll each.
  def pierced_targets(target, weapon_data)
    count = [weapon_data&.dig("pierce_targets").to_i, 1].max
    living = living_enemies
    start = living.index(target)
    Array.new([count, living.size].min) { |i| living[(start + i) % living.size] }
  end

  def resolve_attack_on(target, weapon_data)
    acc_mastery, acc_bonus = player_accuracy(weapon_data)
    def_mastery, def_bonus = enemy_defense(target)

    hit_result = DiceRoller.opposed_roll(acc_mastery, acc_bonus, def_mastery, def_bonus)

    if hit_result[:hit] || hit_result[:graze]
      dmg_mastery, dmg_bonus = player_damage(weapon_data)
      dmg_mastery = graze_mastery(dmg_mastery, hit_result)
      res_mastery, res_bonus = enemy_resistance(target)

      dmg_roll = DiceRoller.roll(dmg_mastery, dmg_bonus)
      res_roll = DiceRoller.roll(res_mastery, res_bonus)
      raw = [dmg_roll[:total] - res_roll[:total], 1].max
      mod = apply_target_resistance(raw, target, "physical")
      final_damage = mod[:immune] ? 0 : [mod[:damage], 1].max

      target[:hp] = [target[:hp] - final_damage, 0].max
      hit_label = hit_result[:graze] ? "touché de peu" : "touché"
      @log << "Vous attaquez #{target[:name]} : #{hit_label} ! (#{hit_result[:attack][:total]} vs #{hit_result[:defense][:total]})"
      tail = mod[:descriptor].present? ? "#{mod[:descriptor]} → #{final_damage}" : ""
      @log << "Dégâts : #{dmg_roll[:total]} - #{res_roll[:total]} résistance = #{raw}#{tail} (#{target[:hp]}/#{target[:max_hp]} PV)"
      weapon_enchantment_hit!(target)
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

    if tech_data["cooldown"].to_i.positive?
      (@state[:technique_cooldowns] ||= {})[technique_key.to_sym] = tech_data["cooldown"].to_i
      @used_technique = technique_key
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
    when "counter"
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
    when "summon"
      resolve_magic_summon(magic_data)
    when "raise_dead"
      resolve_magic_raise_dead(magic_data)
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

    unless COMBAT_ITEM_EFFECTS.include?(item_data["effect_type"])
      @log << "#{item_data["name"]} ne peut pas être utilisé en combat."
      return
    end

    case item_data["effect_type"]
    when "heal"
      heal = DiceRoller.roll(item_data["heal_mastery"] || 1, item_data["value"] || 0)[:total]
      heal = [heal, @state[:player][:max_hp] - @state[:player][:hp]].min
      @state[:player][:hp] += heal
      @log << "Vous utilisez #{item_data["name"]} et récupérez #{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})."
    when "restore_mana"
      restore = DiceRoller.roll(item_data["heal_mastery"] || 1, item_data["value"] || 0)[:total]
      restore = [restore, @state[:player][:max_mana] - @state[:player][:mana]].min
      @state[:player][:mana] += restore
      @log << "Vous utilisez #{item_data["name"]} et récupérez #{restore} mana (#{@state[:player][:mana]}/#{@state[:player][:max_mana]})."
    when "cure_status"
      resolve_item_cure(item_data)
    when "damage"
      resolve_item_damage(item_data)
    when "combat_buff"
      apply_status_to_player(item_data["status"], item_data["status_duration"] || 3, fresh: true)
      @log << "Vous buvez #{item_data["name"]} : vous êtes #{item_data["status"]} (#{item_data["status_duration"] || 3} tours)."
    when "enemy_status"
      targets = item_data["target"] == "all_enemies" ? living_enemies : living_enemies.first(1)
      targets.each { |t| apply_status_to_enemy(t, item_data["status"], item_data["status_duration"] || 2) }
      @log << "Vous lancez #{item_data["name"]} : #{targets.map { |t| t[:name] }.join(', ')} #{targets.size > 1 ? 'sont' : 'est'} #{item_data["status"]} !"
    when "escape"
      return unless resolve_item_escape(item_data)
    end

    if inv_item.quantity > 1
      inv_item.update!(quantity: inv_item.quantity - 1)
    else
      inv_item.destroy!
    end
  end

  # Fire/elemental damage from a thrown item, on one or every enemy (elemental resistances apply).
  def resolve_item_damage(item_data)
    targets = item_data["target"] == "all_enemies" ? living_enemies : living_enemies.first(1)
    @log << "Vous lancez #{item_data["name"]} !"
    targets.each do |target|
      raw = DiceRoller.roll(item_data["damage_mastery"] || 1, item_data["damage_bonus"] || 0)[:total]
      mod = apply_target_resistance(raw, target, :magical, item_data["element"])
      dmg = mod[:immune] ? 0 : [mod[:damage], 1].max
      target[:hp] = [target[:hp] - dmg, 0].max
      @log << "#{target[:name]} subit #{dmg} dégâts#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]} PV)"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    end
  end

  # Guaranteed flee. Returns false (item kept) when it can't work here.
  def resolve_item_escape(item_data)
    floor = @state[:floor].to_i
    if floor.zero?
      @log << "#{item_data["name"]} : impossible de fuir pendant un siège."
      return false
    end
    if !item_data["works_on_boss"] && GameCatalog.floor(floor)&.dig("boss")
      @log << "#{item_data["name"]} est sans effet face à un boss."
      return false
    end

    @log << "Vous utilisez #{item_data["name"]} et disparaissez du combat !"
    @escaped = true
  end

  def resolve_item_cure(item_data)
    wanted = item_data["status_removed"]
    statuses = @state[:player_statuses] || []
    cured = statuses.select do |s|
      if wanted == "any_negative" then status_is_negative?(s[:name])
      else Array(wanted).include?(s[:name])
      end
    end
    @state[:player_statuses] = statuses - cured
    @log << if cured.any?
              "Vous utilisez #{item_data['name']} : statuts retirés (#{cured.pluck(:name).join(', ')})."
            else
              "Vous utilisez #{item_data['name']}, sans effet."
            end
  end

  # ═══════════════════════════════════════════
  # Technique sub-resolvers
  # ═══════════════════════════════════════════

  def resolve_modified_attack(tech)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    weapon_data = equipped_weapon_data
    hit =
      if tech["auto_hit"]
        { hit: true, graze: false }
      else
        acc_m, acc_b = player_accuracy(weapon_data)
        acc_b += (tech["accuracy_bonus"] || 0)
        def_m, def_b = enemy_defense(target)
        DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      end

    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_b += (tech["damage_bonus"] || 0)
      dmg_m += (tech["damage_mastery_mod"] || 0)
      dmg_m = [dmg_m, 1].max
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      raw = [dmg[:total] - res[:total], 1].max
      mod = apply_target_resistance(raw, target, "physical")
      final = mod[:immune] ? 0 : [mod[:damage], 1].max

      target[:hp] = [target[:hp] - final, 0].max
      hit_label = hit[:graze] ? "touché de peu" : "touché"
      @log << "#{tech["name"]} sur #{target[:name]} : #{hit_label} ! #{final} dégâts#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]} PV)"

      if hit[:hit] && tech["inflict_status"]
        chance = tech["status_chance"] || 100
        if rand(100) < chance
          apply_status_to_enemy(target, tech["inflict_status"], tech["status_duration"] || 2)
        end
      end

      weapon_enchantment_hit!(target)
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
      if hit[:hit] || hit[:graze]
        dmg_m, dmg_b = player_damage(weapon_data)
        dmg_m += (tech["damage_mastery_mod"] || 0)
        dmg_m = [dmg_m, 1].max
        dmg_m = graze_mastery(dmg_m, hit)
        res_m, res_b = enemy_resistance(target)

        dmg = DiceRoller.roll(dmg_m, dmg_b)
        res = DiceRoller.roll(res_m, res_b)
        raw = [dmg[:total] - res[:total], 1].max
        mod = apply_target_resistance(raw, target, "physical")
        final = mod[:immune] ? 0 : [mod[:damage], 1].max

        target[:hp] = [target[:hp] - final, 0].max
        suffix = hit[:graze] ? " (touché de peu)" : ""
        @log << "#{tech["name"]} (frappe #{i + 1}) sur #{target[:name]} : #{final} dégâts#{suffix}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"
        weapon_enchantment_hit!(target)
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
      if hit[:hit] || hit[:graze]
        dmg_m, dmg_b = player_damage(weapon_data)
        dmg_m += (tech["damage_mastery_mod"] || 0)
        dmg_b += (tech["damage_bonus"] || 0)
        dmg_m = [dmg_m, 1].max
        dmg_m = graze_mastery(dmg_m, hit)
        res_m, res_b = enemy_resistance(target)

        dmg = DiceRoller.roll(dmg_m, dmg_b)
        res = DiceRoller.roll(res_m, res_b)
        raw = [dmg[:total] - res[:total], 1].max
        mod = apply_target_resistance(raw, target, "physical")
        final = mod[:immune] ? 0 : [mod[:damage], 1].max

        target[:hp] = [target[:hp] - final, 0].max
        suffix = hit[:graze] ? " (touché de peu)" : ""
        @log << "#{tech["name"]} → #{target[:name]} : #{final} dégâts#{suffix}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"
        weapon_enchantment_hit!(target)
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
    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = enemy_resistance(target)
      reduction_pct = tech["dr_reduction_percent"] || 50
      res_m = (res_m * (100 - reduction_pct) / 100.0).ceil
      res_b = (res_b * (100 - reduction_pct) / 100.0).ceil

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      raw = [dmg[:total] - res[:total], 1].max
      mod = apply_target_resistance(raw, target, "physical")
      final = mod[:immune] ? 0 : [mod[:damage], 1].max

      target[:hp] = [target[:hp] - final, 0].max
      suffix = hit[:graze] ? " (touché de peu)" : ""
      @log << "#{tech["name"]} perce la défense de #{target[:name]} : #{final} dégâts !#{suffix}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"
      weapon_enchantment_hit!(target)
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
    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      raw = [dmg[:total] - res[:total], 1].max
      raw *= (tech["damage_multiplier"] || 2) if low_hp && hit[:hit]
      mod = apply_target_resistance(raw, target, "physical")
      final = mod[:immune] ? 0 : [mod[:damage], 1].max

      target[:hp] = [target[:hp] - final, 0].max
      bonus_text = (low_hp && hit[:hit]) ? " (EXÉCUTION !)" : (hit[:graze] ? " (touché de peu)" : "")
      @log << "#{tech["name"]} sur #{target[:name]}#{bonus_text} : #{final} dégâts#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"
      weapon_enchantment_hit!(target)
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
    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_b += (tech["damage_bonus"] || 0)
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      raw = [dmg[:total] - res[:total], 1].max
      mod = apply_target_resistance(raw, target, "physical")
      final = mod[:immune] ? 0 : [mod[:damage], 1].max

      target[:hp] = [target[:hp] - final, 0].max

      if hit[:hit]
        debuff_type = tech["debuff"]
        debuff_val = tech["debuff_value"] || 1
        target[:debuffs] ||= {}
        target[:debuffs][debuff_type] = (target[:debuffs][debuff_type] || 0) + debuff_val
        @log << "#{tech["name"]} : #{final} dégâts#{mod[:descriptor]} + #{debuff_type} (#{target[:name]})"
      else
        @log << "#{tech["name"]} : #{final} dégâts#{mod[:descriptor]} (touché de peu, pas de debuff) (#{target[:name]})"
      end
      weapon_enchantment_hit!(target)
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
    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = player_damage(weapon_data)
      dmg_b += (tech["damage_bonus"] || 0)
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = enemy_resistance(target)

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      raw = [dmg[:total] - res[:total], 1].max
      mod = apply_target_resistance(raw, target, "physical")
      final = mod[:immune] ? 0 : [mod[:damage], 1].max

      target[:hp] = [target[:hp] - final, 0].max
      if hit[:hit]
        apply_status_to_enemy(target, tech["inflict_status"], tech["status_duration"] || 2)
        @log << "#{tech["name"]} : #{final} dégâts#{mod[:descriptor]} + #{tech["inflict_status"]} sur #{target[:name]} (#{target[:hp]}/#{target[:max_hp]})"
      else
        @log << "#{tech["name"]} : #{final} dégâts#{mod[:descriptor]} (touché de peu, pas de statut) sur #{target[:name]} (#{target[:hp]}/#{target[:max_hp]})"
      end
      weapon_enchantment_hit!(target)
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{tech["name"]} : raté !"
    end
  end

  # Every enemy attack the player dodges or parries until their next action is countered.
  def resolve_counter_stance(tech)
    @state[:player_counter] = { counter_damage_bonus: tech["counter_damage_bonus"].to_i }
    @log << "#{tech["name"]} : vous guettez la moindre ouverture."
  end

  # Defense dice (dodge or parry, whichever is active) and/or resistance dice
  # until the player's next action.
  def resolve_stance(tech)
    defense = tech["defense_mastery"].to_i
    dr = tech["dr_mastery"].to_i
    @state[:player_stance] = { defense_mastery: defense, dr_mastery: dr }
    effects = []
    effects << "+#{defense}D #{parry_mode? ? 'parade' : 'esquive'}" if defense.positive?
    effects << "+#{dr}D résistance" if dr.positive?
    @log << "#{tech["name"]} : #{effects.join(', ')} jusqu'à votre prochaine action."
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
    acc_m, acc_b = magic_accuracy(element)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit] || hit[:graze]
      dmg = spell_damage(magic, hit)
      mod = apply_target_resistance(dmg[:total], target, "magical", element)
      final = mod[:immune] ? 0 : [mod[:damage], 0].max
      target[:hp] = [target[:hp] - final, 0].max
      suffix = hit[:graze] ? " (touché de peu)" : ""
      @log << "#{magic["name"]} sur #{target[:name]} : #{final} dégâts !#{suffix}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"

      if hit[:hit] && with_status && magic["inflict_status"] && !mod[:immune]
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
    acc_m, acc_b = magic_accuracy(element)

    living_enemies.each do |target|
      def_m, def_b = enemy_defense(target)
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)

      if hit[:hit] || hit[:graze]
        dmg = spell_damage(magic, hit)
        mod = apply_target_resistance(dmg[:total], target, "magical", element)
        final = mod[:immune] ? 0 : [mod[:damage], 0].max
        target[:hp] = [target[:hp] - final, 0].max
        suffix = hit[:graze] ? " (touché de peu)" : ""
        @log << "#{magic["name"]} → #{target[:name]} : #{final} dégâts#{suffix}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"

        if hit[:hit] && magic["inflict_status"] && !mod[:immune]
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
    heal =
      if magic["heal_percent"]
        (@state[:player][:max_hp] * magic["heal_percent"] / 100.0).ceil
      else
        DiceRoller.roll(magic["heal_mastery"] || 1, magic["heal_bonus"] || 0)[:total]
      end
    @state[:player][:hp] = [@state[:player][:hp] + heal, @state[:player][:max_hp]].min
    @log << "#{magic["name"]} : +#{heal} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"

    if cure
      removed = (@state[:player_statuses] || []).select { |s| status_is_negative?(s[:name]) }.map { |s| s[:name] }
      @state[:player_statuses]&.reject! { |s| status_is_negative?(s[:name]) }
      @log << "Statuts négatifs retirés : #{removed.join(", ")}" if removed.any?
    end
  end

  # Opposed roll like any spell: a clean hit applies the status, a graze only
  # deals the (reduced) damage, an element immunity blocks both.
  def resolve_magic_status(magic)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    element = magic["element"]
    if immune_to_element?(target, element)
      @log << "#{magic["name"]} : #{target[:name]} est immunisé (#{ELEMENT_LABELS[element] || element}), aucun effet."
      return
    end

    acc_m, acc_b = magic_accuracy(element)
    def_m, def_b = enemy_defense(target)
    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    unless hit[:hit] || hit[:graze]
      @log << "#{magic["name"]} sur #{target[:name]} : raté ! (#{hit[:attack][:total]} vs #{hit[:defense][:total]})"
      return
    end

    if magic["damage_mastery"].to_i.positive?
      dmg = spell_damage(magic, hit)
      mod = apply_target_resistance(dmg[:total], target, "magical", element)
      final = [mod[:damage], 0].max
      target[:hp] = [target[:hp] - final, 0].max
      @log << "#{magic["name"]} inflige #{final} dégâts à #{target[:name]}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})."
    end

    if hit[:hit]
      apply_status_to_enemy(target, magic["inflict_status"], magic["status_duration"] || 2)
      @log << "#{target[:name]} est #{magic["inflict_status"]} !"
    else
      @log << "#{magic["name"]} : touché de peu, #{target[:name]} n'est pas #{magic["inflict_status"]}."
    end
    @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
  end

  def resolve_magic_drain(magic)
    target = living_enemies.first
    return @log << "Aucune cible." unless target

    element = magic["element"]
    acc_m, acc_b = magic_accuracy(element)
    def_m, def_b = enemy_defense(target)

    hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
    if hit[:hit] || hit[:graze]
      dmg = spell_damage(magic, hit)
      mod = apply_target_resistance(dmg[:total], target, "magical", element)
      final = mod[:immune] ? 0 : [mod[:damage], 0].max
      target[:hp] = [target[:hp] - final, 0].max
      drain_pct = magic["drain_percent"] || 50
      healed = (final * drain_pct / 100.0).ceil
      @state[:player][:hp] = [@state[:player][:hp] + healed, @state[:player][:max_hp]].min

      suffix = hit[:graze] ? " (touché de peu)" : ""
      @log << "#{magic["name"]} : #{final} dégâts, +#{healed} PV drainés#{suffix}#{mod[:descriptor]} (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"
      @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
    else
      @log << "#{magic["name"]} : raté !"
    end
  end

  def resolve_magic_buff(magic)
    buffs = Array(magic["buff_statuses"] || magic["buff_status"])
    buff_duration = magic["buff_duration"] || 2
    buffs.each { |name| apply_status_to_player(name, buff_duration, fresh: true) }
    @log << "#{magic["name"]} : #{buffs.join(' et ')} pendant #{buff_duration} tour#{'s' if buff_duration > 1}."

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

  # ═══════════════════════════════════════════
  # Initiative and round flow
  # A round is: faster enemies → player → slower enemies → status ticks.
  # The player's input arrives in the middle of a round, so each request runs
  # player → slower enemies → ticks, then the faster enemies of the next round.
  # ═══════════════════════════════════════════

  def roll_initiative!
    mastery, bonus = character.initiative_roll
    @state[:player_initiative] = DiceRoller.roll(mastery, bonus)[:total]
    @state[:enemies].each do |enemy|
      speed = enemy[:vitesse] || { mastery: 1, bonus: 0 }
      enemy[:initiative] = DiceRoller.roll(speed[:mastery], speed[:bonus])[:total]
    end

    order = @state[:enemies].map { |e| [e[:name], e[:initiative]] } + [["Vous", @state[:player_initiative]]]
    order = order.sort_by { |name, init| [-init, name == "Vous" ? 0 : 1] }
    @state[:log] << "Initiative (Vitesse #{DiceRoller.notation(mastery, bonus)}) : " +
      order.map { |name, init| "#{name} #{init}" }.join(" > ")
  end

  # Ties go to the player.
  def faster_than_player?(enemy)
    enemy[:initiative].to_i > @state[:player_initiative].to_i
  end

  def enemies_by_initiative
    living_enemies.sort_by.with_index { |e, i| [-e[:initiative].to_i, i] }
  end

  def faster_enemies
    enemies_by_initiative.select { |e| faster_than_player?(e) }
  end

  def slower_enemies
    enemies_by_initiative.reject { |e| faster_than_player?(e) }
  end

  # Combats saved before initiative existed: roll it now, no opening phase.
  def resume_legacy_combat!
    return if @state[:player_initiative]

    roll_initiative!
    @state[:turn] = @state[:turn].to_i + 1
    start_round_log!
  end

  def start_round_log!
    @state[:round_attacks] = 0
    (@state[:allies] || []).each { |a| a[:round_attacks] = 0 }
    @state[:riposte_used] = false
    @log << "--- Tour #{@state[:turn]} ---"
  end

  # End of the player's action: slower enemies, status ticks, then the next
  # round starts with the faster enemies.
  def close_round
    return finish_combat(:victory) if enemies_all_dead?

    resolve_enemy_turns(slower_enemies)
    return finish_combat(:defeat) if player_dead?
    return finish_combat(:victory) if enemies_all_dead?

    tick_all_statuses
    return finish_combat(:defeat) if player_dead?
    return finish_combat(:victory) if enemies_all_dead?

    @state[:turn] += 1
    start_round_log!
    end_turn_with { resolve_enemy_turns(faster_enemies) }
  end

  def end_turn_with
    yield
    return finish_combat(:defeat) if player_dead?
    return finish_combat(:victory) if enemies_all_dead?

    plan_enemy_intents!
    @state[:log].concat(@log)
    save_state!
    combat_snapshot
  end

  def resolve_enemy_turns(enemies)
    enemies.each do |enemy|
      break if player_dead?
      next if enemy[:hp] <= 0

      intent = enemy.delete(:intent) || roll_enemy_intent(enemy)
      enemy.delete(:intent_known)
      ally = intent[:target] && allies[intent[:target]]
      unless enemy_is_stunned?(enemy) || enemy_is_paralyzed?(enemy)
        if ally && ally[:hp] > 0
          resolve_enemy_vs_ally(enemy, ally, intent[:ability])
        elsif intent[:ability]
          resolve_enemy_ability(enemy, intent[:ability])
        else
          resolve_enemy_attack(enemy)
        end
      end
      # Statuses count down at the end of their bearer's own turn (see tick_player_statuses).
      tick_enemy_statuses(enemy) if enemy[:hp] > 0
    end
  end

  # Next action of an enemy: one of its abilities (ability_chance %) or a basic attack.
  def roll_enemy_intent(enemy)
    use_ability = enemy[:abilities]&.any? && rand(100) < (enemy[:ability_chance] || DEFAULT_ABILITY_CHANCE)
    ability = use_ability ? enemy[:abilities].sample : nil
    { ability: ability, target: roll_enemy_target(ability) }
  end

  # Index of the summoned creature an enemy blow aims at (nil = the player), from
  # each creature's `taunt` %. Heals and non-damage spells always concern the player.
  def roll_enemy_target(ability_key)
    return nil if living_allies.empty?

    if ability_key
      data = GameCatalog.technique_data(ability_key) || GameCatalog.magic_data(ability_key)
      return nil if data && data["mana_cost"] && !%w[damage damage_status drain].include?(data["type"])
    end
    allies.each_with_index { |a, i| return i if a[:hp] > 0 && rand(100) < a[:taunt].to_i }
    nil
  end

  def intent_label(intent)
    target = intent&.dig(:target) && allies[intent[:target]]
    suffix = target && target[:hp] > 0 ? " (vise #{target[:name]})" : ""
    return "attaque#{suffix}" unless intent&.dig(:ability)

    ability = GameCatalog.technique_data(intent[:ability]) || GameCatalog.magic_data(intent[:ability])
    (ability ? ability["name"] : "attaque") + suffix
  end

  # Decides every enemy's next action in advance, then one Intuition roll
  # reveals the intent of each enemy whose difficulty (5 + 2 × its attack dice) it beats.
  def plan_enemy_intents!
    enemies = living_enemies
    return if enemies.empty?

    enemies.each do |enemy|
      enemy[:intent] = roll_enemy_intent(enemy)
      enemy[:intent_known] = false
    end

    skill = character.skills.find_by(name: "Intuition")
    mastery, bonus = skill ? [skill.mastery, skill.bonus] : [character.perception, 0]
    total = DiceRoller.roll(mastery, bonus)[:total]
    guessed = enemies.select { |e| total >= intuition_difficulty(e) }
    guessed.each { |e| e[:intent_known] = true }

    found = guessed.map { |e| "#{e[:name]} : #{intent_label(e[:intent])}" }
    @log << "Intuition (#{DiceRoller.notation(mastery, bonus)}) : #{total} — " +
      (found.any? ? found.join(" · ") : "vous ne devinez pas les intentions ennemies.")
  end

  def intuition_difficulty(enemy)
    5 + 2 * enemy[:attack][:mastery].to_i
  end

  def resolve_enemy_attack(enemy)
    att_m = enemy[:attack][:mastery]
    att_b = enemy[:attack][:bonus]
    apply_enemy_status_mods_attack(enemy, att_m, att_b) => { mastery: att_m, bonus: att_b }

    def_m, def_b = player_defense_vs(enemy)

    hit = DiceRoller.opposed_roll(att_m, att_b, def_m, def_b)
    @state[:round_attacks] = @state[:round_attacks].to_i + 1
    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = enemy_damage_dice(enemy)
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = player_resistance_dice

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 1].max

      hurt_player!(final)
      suffix = hit[:graze] ? " (touché de peu)" : ""
      @log << "#{enemy[:name]} vous attaque : #{final} dégâts !#{suffix} (#{@state[:player][:hp]}/#{@state[:player][:max_hp]} PV)"
      @log << "Vous êtes tombé au combat !" if @state[:player][:hp] <= 0
      thorns_hit!(enemy)
    else
      defended!("#{enemy[:name]} vous attaque")
      counter_after_defense(enemy)
    end
  end

  def resolve_enemy_ability(enemy, ability_key = enemy[:abilities].sample)
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
    apply_enemy_status_mods_attack(enemy, att_m, att_b) => { mastery: att_m, bonus: att_b }
    def_m, def_b = player_defense_vs(enemy)

    hit = DiceRoller.opposed_roll(att_m, att_b, def_m, def_b)
    @state[:round_attacks] = @state[:round_attacks].to_i + 1
    if hit[:hit] || hit[:graze]
      dmg_m, dmg_b = enemy_damage_dice(enemy, tech["damage_mastery_mod"].to_i, tech["damage_bonus"].to_i)
      dmg_m = graze_mastery(dmg_m, hit)
      res_m, res_b = player_resistance_dice

      dmg = DiceRoller.roll(dmg_m, dmg_b)
      res = DiceRoller.roll(res_m, res_b)
      final = [dmg[:total] - res[:total], 1].max

      hurt_player!(final)
      suffix = hit[:graze] ? " (touché de peu)" : ""
      @log << "#{enemy[:name]} utilise #{tech["name"]} : #{final} dégâts !#{suffix}"
      thorns_hit!(enemy)

      if hit[:hit] && tech["inflict_status"]
        chance = tech["status_chance"] || 100
        inflict_status_on_player(tech["inflict_status"], tech["status_duration"] || 2, enemy) if rand(100) < chance
      end
    else
      defended!("#{enemy[:name]} utilise #{tech["name"]}")
      counter_after_defense(enemy)
    end
  end

  def resolve_enemy_magic_ability(enemy, magic)
    apply_enemy_status_mods_attack(enemy, enemy[:attack][:mastery], enemy[:attack][:bonus]) => { mastery: acc_m, bonus: acc_b }

    case magic["type"]
    when "heal"
      heal = DiceRoller.roll(magic["heal_mastery"] || 1, magic["heal_bonus"] || 0)[:total]
      enemy[:hp] = [enemy[:hp] + heal, enemy[:max_hp]].min
      @log << "#{enemy[:name]} lance #{magic["name"]} et récupère #{heal} PV (#{enemy[:hp]}/#{enemy[:max_hp]})"
      return
    when "damage", "damage_status"
      def_m, def_b = player_defense_vs(enemy)
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      @state[:round_attacks] = @state[:round_attacks].to_i + 1
      if hit[:hit] || hit[:graze]
        dmg_m = magic["damage_mastery"] || 1
        dmg_m = graze_mastery(dmg_m, hit)
        dmg = reduce_by_magic_resistance(DiceRoller.roll(dmg_m, magic["damage_bonus"] || 0)[:total])
        hurt_player!(dmg)
        suffix = hit[:graze] ? " (touché de peu)" : ""
        @log << "#{enemy[:name]} lance #{magic["name"]} : #{dmg} dégâts !#{suffix}"

        if hit[:hit] && magic["inflict_status"]
          chance = magic["status_chance"] || 50
          inflict_status_on_player(magic["inflict_status"], magic["status_duration"] || 2, enemy) if rand(100) < chance
        end
      else
        defended!("#{enemy[:name]} lance #{magic["name"]}")
      end
    when "drain"
      def_m, def_b = player_defense_vs(enemy)
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      @state[:round_attacks] = @state[:round_attacks].to_i + 1
      if hit[:hit] || hit[:graze]
        dmg_m = magic["damage_mastery"] || 1
        dmg_m = graze_mastery(dmg_m, hit)
        dmg = reduce_by_magic_resistance(DiceRoller.roll(dmg_m, magic["damage_bonus"] || 0)[:total])
        hurt_player!(dmg)
        healed = (dmg * (magic["drain_percent"] || 50) / 100.0).ceil
        enemy[:hp] = [enemy[:hp] + healed, enemy[:max_hp]].min
        suffix = hit[:graze] ? " (touché de peu)" : ""
        @log << "#{enemy[:name]} lance #{magic["name"]} : #{dmg} dégâts, +#{healed} PV drainés#{suffix}"
      else
        defended!("#{enemy[:name]} lance #{magic["name"]}")
      end
    when "status"
      def_m, def_b = player_defense_vs(enemy)
      hit = DiceRoller.opposed_roll(acc_m, acc_b, def_m, def_b)
      @state[:round_attacks] = @state[:round_attacks].to_i + 1
      if hit[:hit] && magic["inflict_status"]
        @log << "#{enemy[:name]} lance #{magic["name"]} !"
        inflict_status_on_player(magic["inflict_status"], magic["status_duration"] || 2, enemy)
      else
        @log << "#{enemy[:name]} lance #{magic["name"]} : raté !"
      end
    else
      resolve_enemy_attack(enemy)
    end
  end

  # Negative status from an enemy. Mental ones can be resisted (or shortened)
  # with a Sang-Froid roll against the enemy's attack roll.
  def inflict_status_on_player(status_name, duration, enemy)
    if MENTAL_STATUSES.include?(status_name)
      skill = character.skills.find_by(name: "Sang-Froid")
      mastery, bonus = skill ? [skill.mastery, skill.bonus] : [character.perception, 0]
      bonus += character.passive_item("sang_froid_bonus")&.dig("value").to_i
      own = DiceRoller.roll(mastery, bonus)[:total]
      against = DiceRoller.roll(enemy[:attack][:mastery], enemy[:attack][:bonus])[:total]
      label = "Sang-Froid (#{DiceRoller.notation(mastery, bonus)}) : #{own} vs #{against}"

      if own >= against
        @log << "#{label} — vous résistez à #{status_name} !"
        return
      elsif against - own <= SANG_FROID_PARTIAL_MARGIN && duration > 1
        duration -= 1
        @log << "#{label} — vous vous ressaisissez en partie (#{status_name} #{duration} tour#{'s' if duration > 1})."
      else
        @log << "#{label} — échec."
      end
    end

    apply_status_to_player(status_name, duration)
    @log << "Vous êtes #{status_name} !"
  end

  def resolve_player_counter_hit(enemy, counter, label = "Contre-attaque")
    weapon_data = equipped_weapon_data
    dmg_m, dmg_b = player_damage(weapon_data)
    dmg_b += (counter[:counter_damage_bonus] || 0)
    res_m, res_b = enemy_resistance(enemy)

    dmg = DiceRoller.roll(dmg_m, dmg_b)
    res = DiceRoller.roll(res_m, res_b)
    raw = [dmg[:total] - res[:total], 1].max
    mod = apply_target_resistance(raw, enemy, "physical")
    final = mod[:immune] ? 0 : [mod[:damage], 1].max

    enemy[:hp] = [enemy[:hp] - final, 0].max
    @log << "#{label} ! #{final} dégâts à #{enemy[:name]}#{mod[:descriptor]} (#{enemy[:hp]}/#{enemy[:max_hp]})"
    weapon_enchantment_hit!(enemy)
    @log << "#{enemy[:name]} est vaincu !" if enemy[:hp] <= 0
  end

  # After a dodged/parried enemy blow: the "Contre-attaque" stance counters every one,
  # the "Riposte" passive the first parried blow of each round.
  def counter_after_defense(enemy)
    return if enemy[:hp] <= 0 || player_dead?

    if @state[:player_counter]
      resolve_player_counter_hit(enemy, @state[:player_counter])
    elsif parry_mode? && !@state[:riposte_used] && passive_technique?("riposte")
      @state[:riposte_used] = true
      resolve_player_counter_hit(enemy, {}, "Riposte")
    end
  end

  # Every damage the player takes goes through here, for the "Survie" passive:
  # once per fight, a blow that would kill the player leaves them at 1 PV.
  def hurt_player!(amount)
    hp = @state[:player][:hp]
    if hp.positive? && hp - amount <= 0 && !@state[:survival_used] && passive_technique?("survival")
      @state[:survival_used] = true
      @state[:player][:hp] = 1
      @log << "Survie : vous encaissez un coup fatal et tenez bon à 1 PV !"
    else
      @state[:player][:hp] = hp - amount
    end
  end

  # ═══════════════════════════════════════════
  # Summoned creatures (Invocation)
  # One creature at a time, fighting on the player's side until it is destroyed
  # or the fight ends. It acts right after the player; enemies aim at it with
  # its `taunt` % (decided with their intent). It never receives statuses.
  # ═══════════════════════════════════════════

  def allies
    @state[:allies] ||= []
  end

  def living_allies
    allies.select { |a| a[:hp] > 0 }
  end

  def resolve_magic_summon(magic)
    data = GameCatalog.summon(magic["summon"])
    return @log << "#{magic["name"]} : invocation inconnue." unless data

    ally = build_ally(data)
    place_ally!(ally)
    @log << "Vous invoquez #{ally[:name]} (#{ally[:hp]} PV) ! Il agira dès votre prochain tour."
  end

  # One creature at a time (summoned or raised): the new one replaces the previous.
  def place_ally!(ally)
    living_allies.each { |a| @log << "#{a[:name]} #{a[:undead] ? "retombe en poussière" : "retourne d'où il vient"}." }
    @state[:allies] = [ally]
    # Enemies already planned their next action: let them pick their target again.
    living_enemies.each { |e| e[:intent][:target] = roll_enemy_target(e[:intent][:ability]) if e[:intent] }
  end

  # Nécromancie: the strongest fallen enemy of this fight, except the boss, once each.
  def raisable_corpse
    (@state[:enemies] || []).select { |e| e[:hp] <= 0 && !e[:boss] && !e[:raised] }.max_by { |e| e[:max_hp] }
  end

  NECROMANCY_GRADES = [
    { margin: 10, hp_percent: 100, dice: 1, label: "réussite éclatante" },
    { margin: 5, hp_percent: 75, dice: 0, label: "bonne réussite" },
    { margin: 0, hp_percent: 50, dice: -1, label: "réussite de peu" }
  ].freeze

  # Ombre roll (fallback Intelligence) vs 5 + 2 × the corpse's attack dice; the margin
  # sets the undead's PV (% of the monster's) and attack/damage dice. A failure
  # crumbles the corpse. Basic attacks only, never statuses, like a summon.
  def resolve_magic_raise_dead(magic)
    corpse = raisable_corpse
    return @log << "#{magic["name"]} : aucun ennemi tombé à relever." unless corpse

    corpse[:raised] = true
    skill = find_player_skill_for_element("ombre")
    mastery, bonus = skill ? [skill.mastery, skill.bonus] : [character.intelligence, 0]
    total = DiceRoller.roll(mastery, bonus)[:total]
    difficulty = intuition_difficulty(corpse)
    label = "#{magic["name"]} (Ombre #{DiceRoller.notation(mastery, bonus)}) : #{total} vs #{difficulty}"
    grade = NECROMANCY_GRADES.find { |g| total - difficulty >= g[:margin] }
    unless grade
      @log << "#{label} — le cadavre de #{corpse[:name]} se désagrège."
      return
    end

    hp = [(corpse[:max_hp] * grade[:hp_percent] / 100.0).ceil, 1].max
    dice = ->(h, add = 0) { { mastery: [h[:mastery].to_i + add, 1].max, bonus: h[:bonus].to_i } }
    ally = {
      key: corpse[:key], name: "#{corpse[:name]} (mort-vivant)", hp: hp, max_hp: hp,
      attack: dice.(corpse[:attack], grade[:dice]), damage: dice.(corpse[:damage], grade[:dice]),
      esquive: dice.(corpse[:esquive]), vigueur: dice.(corpse[:vigueur]), dr: dice.(corpse[:dr]),
      taunt: (magic["taunt"] || 50).to_i, role: "attack", damage_kind: "physical", aoe: false, rebirth: false,
      status_chance: 0, status_duration: 2, summoned_turn: @state[:turn], round_attacks: 0,
      undead: true, image_dir: "monsters"
    }
    @log << "#{label} — #{grade[:label]} !"
    place_ally!(ally)
    @log << "#{corpse[:name]} se relève sous vos ordres (#{hp} PV) ! Il agira dès votre prochain tour."
  end

  # Creature stats grow with the Invocation skill: +hp_per_die PV per die above 1,
  # +1D attack/damage (+1 heal) per `attack_dice_per_dice` dice above 1.
  def build_ally(data)
    level = [character.invocation_mastery - 1, 0].max
    extra = level / [GameCatalog.summons_data.dig("scaling", "attack_dice_per_dice").to_i, 1].max
    dice = ->(h, add = 0) { h && { mastery: h["mastery"].to_i + add, bonus: h["bonus"].to_i } }
    hp = data["hp"].to_i + data["hp_per_die"].to_i * level
    {
      key: data["key"], name: data["name"], hp: hp, max_hp: hp,
      attack: dice.(data["attack"], extra), damage: dice.(data["damage"], extra),
      esquive: dice.(data["esquive"]), vigueur: dice.(data["vigueur"]), dr: dice.(data["dr"]),
      heal: data["heal"] && { mastery: data["heal"]["mastery"].to_i, bonus: data["heal"]["bonus"].to_i + extra },
      taunt: data["taunt"].to_i, role: data["role"] || "attack", damage_kind: data["damage_kind"] || "physical",
      element: data["element"], aoe: data["aoe"] || false, rebirth: data["rebirth"] || false,
      inflict_status: data["inflict_status"], status_chance: data["status_chance"].to_i,
      status_duration: data["status_duration"] || 2, summoned_turn: @state[:turn], round_attacks: 0
    }
  end

  # Right after the player's action (even a lost turn). Not on the turn it was summoned.
  def resolve_ally_turns
    living_allies.each do |ally|
      next if ally[:summoned_turn] == @state[:turn]
      break if enemies_all_dead?

      if ally[:role] == "heal"
        before = @state[:player][:hp]
        heal = DiceRoller.roll(ally[:heal][:mastery], ally[:heal][:bonus])[:total]
        @state[:player][:hp] = [before + heal, @state[:player][:max_hp]].min
        @log << "#{ally[:name]} vous soigne : +#{@state[:player][:hp] - before} PV (#{@state[:player][:hp]}/#{@state[:player][:max_hp]})"
      else
        targets = ally[:aoe] ? living_enemies : living_enemies.first(1)
        targets.each { |t| resolve_ally_attack(ally, t) }
      end
    end
  end

  def resolve_ally_attack(ally, target)
    def_m, def_b = enemy_defense(target)
    hit = DiceRoller.opposed_roll(ally[:attack][:mastery], ally[:attack][:bonus], def_m, def_b)
    unless hit[:hit] || hit[:graze]
      @log << "#{ally[:name]} attaque #{target[:name]} : raté !"
      return
    end

    dmg = DiceRoller.roll(graze_mastery(ally[:damage][:mastery], hit), ally[:damage][:bonus])[:total]
    if ally[:damage_kind] == "magical"
      mod = apply_target_resistance(dmg, target, "magical", ally[:element])
    else
      res_m, res_b = enemy_resistance(target)
      mod = apply_target_resistance([dmg - DiceRoller.roll(res_m, res_b)[:total], 1].max, target, "physical")
    end
    final = mod[:immune] ? 0 : [mod[:damage], 1].max
    target[:hp] = [target[:hp] - final, 0].max
    suffix = hit[:graze] ? " (touché de peu)" : ""
    @log << "#{ally[:name]} attaque #{target[:name]} : #{final} dégâts#{suffix}#{mod[:descriptor]} (#{target[:hp]}/#{target[:max_hp]})"

    if hit[:hit] && ally[:inflict_status] && !mod[:immune] && target[:hp] > 0 && rand(100) < ally[:status_chance]
      apply_status_to_enemy(target, ally[:inflict_status], ally[:status_duration])
      @log << "#{target[:name]} est #{ally[:inflict_status]} !"
    end
    @log << "#{target[:name]} est vaincu !" if target[:hp] <= 0
  end

  # An enemy blow aimed at the creature: attack vs its esquive (−1D per earlier
  # attack on it this round), then physical damage − its resistance roll, or the
  # spell's dice. Statuses carried by the ability are ignored.
  def resolve_enemy_vs_ally(enemy, ally, ability_key)
    ability = ability_key && (GameCatalog.technique_data(ability_key) || GameCatalog.magic_data(ability_key))
    magic = ability && ability["mana_cost"]
    label = ability ? "#{enemy[:name]} utilise #{ability["name"]} sur #{ally[:name]}" : "#{enemy[:name]} attaque #{ally[:name]}"

    accuracy_mod = magic ? 0 : ability&.dig("accuracy_bonus").to_i
    apply_enemy_status_mods_attack(enemy, enemy[:attack][:mastery], enemy[:attack][:bonus] + accuracy_mod) => { mastery: att_m, bonus: att_b }
    def_m = [ally[:esquive][:mastery] - ally[:round_attacks].to_i, 1].max
    ally[:round_attacks] = ally[:round_attacks].to_i + 1
    hit = DiceRoller.opposed_roll(att_m, att_b, def_m, ally[:esquive][:bonus])
    return @log << "#{label} : raté !" unless hit[:hit] || hit[:graze]

    if magic
      dmg = DiceRoller.roll(graze_mastery(ability["damage_mastery"] || 1, hit), ability["damage_bonus"] || 0)[:total]
      if ability["type"] == "drain"
        enemy[:hp] = [enemy[:hp] + (dmg * (ability["drain_percent"] || 50) / 100.0).ceil, enemy[:max_hp]].min
      end
    else
      dmg_m, dmg_b = enemy_damage_dice(enemy, ability&.dig("damage_mastery_mod").to_i, ability&.dig("damage_bonus").to_i)
      res = DiceRoller.roll(ally[:vigueur][:mastery] + ally[:dr][:mastery], ally[:vigueur][:bonus] + ally[:dr][:bonus])[:total]
      dmg = [DiceRoller.roll(graze_mastery(dmg_m, hit), dmg_b)[:total] - res, 1].max
    end
    suffix = hit[:graze] ? " (touché de peu)" : ""
    hurt_ally!(ally, dmg, "#{label} : #{dmg} dégâts#{suffix}")
  end

  def hurt_ally!(ally, amount, message)
    ally[:hp] = [ally[:hp] - amount, 0].max
    @log << "#{message} (#{ally[:hp]}/#{ally[:max_hp]} PV)"
    return if ally[:hp].positive?

    if ally[:rebirth] && !ally[:reborn]
      ally[:reborn] = true
      ally[:hp] = (ally[:max_hp] / 2.0).ceil
      @log << "#{ally[:name]} renaît de ses cendres ! (#{ally[:hp]}/#{ally[:max_hp]} PV)"
    else
      @log << "#{ally[:name]} est détruit !"
    end
  end

  # ═══════════════════════════════════════════
  # Techniques: cooldowns and passives
  # ═══════════════════════════════════════════

  # Error message when the technique can't be used right now (the turn isn't spent).
  def technique_unavailable(technique_key)
    tech = GameCatalog.technique_data(technique_key.to_s)
    return "Technique inconnue" unless tech
    return "Vous ne connaissez pas cette technique" unless learned_technique_keys.include?(technique_key.to_s)
    return "#{tech['name']} est une technique passive, toujours active" if tech["type"] == "passive"

    remaining = (@state[:technique_cooldowns] || {})[technique_key.to_sym].to_i
    "#{tech['name']} est en recharge (#{remaining} tour#{'s' if remaining > 1})" if remaining.positive?
  end

  # One player turn passed: every cooldown but the one just set goes down by 1.
  def tick_technique_cooldowns!(except: nil)
    cooldowns = @state[:technique_cooldowns]
    return if cooldowns.blank?

    cooldowns.each_key do |key|
      next if key.to_s == except.to_s
      cooldowns[key] = [cooldowns[key].to_i - 1, 0].max
    end
    cooldowns.reject! { |_, v| v.zero? }
  end

  def learned_technique_keys
    @learned_technique_keys ||= character.learned_techniques.pluck(:technique_key)
  end

  def passive_technique?(passive_key)
    @passive_keys ||= learned_technique_keys.filter_map { |k| GameCatalog.technique_data(k)&.dig("passive") }
    @passive_keys.include?(passive_key)
  end

  # "Rage du désespoir": +1D weapon damage under its PV threshold.
  def desperate_rage?
    return false unless passive_technique?("desperate_rage")

    threshold = GameCatalog.technique_data("rage_du_desespoir")&.dig("hp_threshold") || 30
    @state[:player][:hp] <= @state[:player][:max_hp] * threshold / 100.0
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
          hurt_player!(dmg)
          @log << "Confus, vous vous frappez vous-même ! #{dmg} dégâts."
          confused = true
        end
      end
    end

    skip || confused
  end

  # End of round: per-round equipment effects only. Statuses count down at the
  # end of their bearer's own turn, so "1 round" always means "its next turn",
  # whatever the initiative order.
  def tick_all_statuses
    tick_player_enchantments
  end

  # End of the player's turn. A status the player gave themselves this very turn
  # (spell, elixir) is skipped once, so a 1-round Invisible lasts until the next action.
  def tick_player_statuses
    @state[:player_statuses] ||= []
    @state[:player_statuses].each do |s|
      next s.delete(:fresh) if s[:fresh]

      status_data = GameCatalog.all_statuses_data[s[:name]]
      next unless status_data

      if status_data["tick_damage_mastery"]
        dmg = DiceRoller.roll(status_data["tick_damage_mastery"], status_data["tick_damage_bonus"] || 0)[:total]
        hurt_player!(dmg)
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

  # `fresh`: self-applied during the player's turn (not counted down at the end of it).
  def apply_status_to_player(status_name, duration, fresh: false)
    @state[:player_statuses] ||= []
    existing = @state[:player_statuses].find { |s| s[:name] == status_name }
    if existing
      existing[:remaining] = [existing[:remaining], duration].max
      existing[:fresh] = true if fresh
    else
      @state[:player_statuses] << { name: status_name, remaining: duration, fresh: fresh || nil }.compact
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

  def graze_mastery(mastery, hit)
    hit[:graze] ? [mastery - 1, 1].max : mastery
  end

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

    mastery, bonus = add_precision_enchantment(mastery, bonus)
    apply_player_accuracy_mods(mastery, bonus)
  end

  def player_damage(weapon_data)
    if weapon_data
      is_ranged = weapon_data["category"] == "arme_a_distance"
      stat = is_ranged ? character.dexterite : character.vigueur
      # Characteristic dice + weapon dice (e.g. Vigueur 2 + weapon 3D+1 = 5D+1)
      mastery = stat + (weapon_data["damage_mastery"] || 0)
      bonus = weapon_data["damage_bonus"] || 0
    else
      mastery = character.vigueur
      bonus = 0
    end

    apply_player_damage_mods(mastery, bonus)
  end

  def enemy_defense(enemy)
    esquive_m = enemy[:esquive][:mastery]
    esquive_b = enemy[:esquive][:bonus]

    (enemy[:statuses] || []).each do |s|
      data = GameCatalog.all_statuses_data[s[:name]]
      next unless data
      esquive_m -= data["defense_mastery_penalty"].to_i + data["mastery_penalty"].to_i
    end

    debuffs = enemy[:debuffs] || {}
    if debuffs["parade_reduction"]
      esquive_b = [esquive_b - debuffs["parade_reduction"], 0].max
    end

    [[esquive_m, 1].max, esquive_b]
  end

  # Enemy damage dice (basic attacks and techniques) with its statuses:
  # Affaibli -1D, Enragé +1D, Terrorisé/Gelé -1D.
  def enemy_damage_dice(enemy, mastery_mod = 0, bonus_mod = 0)
    mastery = enemy[:damage][:mastery] + mastery_mod
    (enemy[:statuses] || []).each do |s|
      data = GameCatalog.all_statuses_data[s[:name]]
      next unless data
      mastery += data["damage_mastery_bonus"].to_i - data["damage_mastery_penalty"].to_i - data["mastery_penalty"].to_i
    end
    [[mastery, 1].max, enemy[:damage][:bonus] + bonus_mod]
  end

  # Player resistance to physical blows: Vigueur + equipment DR, + "Protégé" and stances.
  def player_resistance_dice
    protected_status = (@state[:player_statuses] || []).any? { |s| s[:name] == "Protégé" }
    mastery = character.vigueur + character.total_dr_mastery + (protected_status ? 1 : 0) +
              @state.dig(:player_stance, :dr_mastery).to_i
    [mastery, character.total_dr_bonus]
  end

  def enemy_resistance(enemy)
    vig_m = enemy[:vigueur][:mastery]
    vig_b = enemy[:vigueur][:bonus]
    dr_m = enemy[:dr][:mastery]
    dr_b = enemy[:dr][:bonus]
    [vig_m + dr_m, vig_b + dr_b]
  end

  ELEMENT_LABELS = {
    "physical" => "physique", "magical" => "magique",
    "feu" => "feu", "eau" => "eau", "ombre" => "ombre",
    "lumiere" => "lumière", "nature" => "nature"
  }.freeze

  def apply_target_resistance(raw_damage, target, kind, element = nil)
    resistances = (target[:resistances] || {}).transform_keys(&:to_s)

    value = nil
    key = nil
    if element && resistances.key?(element.to_s)
      value = resistances[element.to_s].to_i
      key = element.to_s
    elsif resistances.key?(kind.to_s)
      value = resistances[kind.to_s].to_i
      key = kind.to_s
    end

    # "Maudit": resistances lowered (a missing one becomes a vulnerability), immunities kept.
    penalty = (target[:statuses] || []).sum { |s| GameCatalog.all_statuses_data.dig(s[:name], "resistance_penalty").to_i }
    if penalty.positive? && value.to_i < 100
      value = value.to_i - penalty
      key ||= element ? element.to_s : kind.to_s
    end

    return { damage: raw_damage, descriptor: "", immune: false, multiplier: 1.0 } if value.nil? || value.zero?

    value = value.clamp(-100, 100)
    multiplier = (100 - value) / 100.0
    final = (raw_damage * multiplier).round
    immune = value >= 100
    label = ELEMENT_LABELS[key] || key

    descriptor = if immune
      " — immunité #{label} !"
    elsif value > 0
      " — résiste #{value}% #{label}"
    else
      " — vulnérabilité #{value.abs}% #{label} !"
    end

    { damage: final, descriptor: descriptor, immune: immune, multiplier: multiplier }
  end

  def parry_mode?
    @parry_mode = character.effective_defense_mode == "parade" if @parry_mode.nil?
    @parry_mode
  end

  # Esquive: higher roll needed, full avoidance. Parade: easier roll
  # (PARRY_ROLL_BONUS), but PARRY_CHIP_DAMAGE still goes through.
  # Technique/stance bonuses only apply to the matching mode.
  def player_defense_vs(_enemy)
    mastery, bonus = character.defense_roll
    bonus += PARRY_ROLL_BONUS if parry_mode?

    mastery += @state.dig(:player_stance, :defense_mastery).to_i

    accel = (@state[:player_statuses] || []).find { |s| s[:name] == "Accéléré" }
    bonus += 1 if accel
    # Béni / Inspiré (+1) and Maudit (-1) apply to every roll, defense included.
    (@state[:player_statuses] || []).each do |s|
      data = GameCatalog.all_statuses_data[s[:name]]
      bonus += data["bonus_all"].to_i - data["bonus_penalty"].to_i if data
    end

    penalty = @state[:round_attacks].to_i
    penalty -= 1 if penalty.positive? && passive_technique?("veteran_instinct")
    if penalty > 0
      mastery = [mastery - penalty, 1].max
      label = parry_mode? ? "Parade" : "Esquive"
      @log << "#{label} affaiblie (-#{penalty}D, attaque n°#{@state[:round_attacks].to_i + 1} du tour)"
    end

    [mastery, bonus]
  end

  # Logs a failed enemy attack. With a parry, the player still takes chip damage.
  def defended!(action_label)
    unless parry_mode?
      @log << "#{action_label} : raté !"
      return
    end

    hurt_player!(PARRY_CHIP_DAMAGE)
    @log << "#{action_label} : paré ! #{PARRY_CHIP_DAMAGE} dégât subi (#{@state[:player][:hp]}/#{@state[:player][:max_hp]} PV)"
    @log << "Vous êtes tombé au combat !" if @state[:player][:hp] <= 0
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
    mastery += 1 if desperate_rage?
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

  # Spell accuracy: element skill (fallback Intelligence) + precision enchantment
  # + the player's statuses (Aveuglé, Concentré, Invisible…), like weapons.
  def magic_accuracy(element)
    skill = find_player_skill_for_element(element)
    mastery, bonus = skill ? [skill.mastery, skill.bonus] : [character.intelligence, 0]
    mastery, bonus = add_precision_enchantment(mastery, bonus)
    apply_player_accuracy_mods(mastery, bonus)
  end

  # Damage spells: +1 per 2 dice of the element skill (fallback Intelligence).
  def spell_power(element)
    (@spell_power ||= {})[element] ||= character.spell_power(element)
  end

  def spell_damage(magic, hit)
    mastery = graze_mastery(magic["damage_mastery"] || 1, hit)
    DiceRoller.roll(mastery, (magic["damage_bonus"] || 0) + spell_power(magic["element"]))
  end

  def immune_to_element?(target, element)
    (target[:resistances] || {}).transform_keys(&:to_s)[element.to_s].to_i >= 100
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

  # Flee roll: Dextérité (+ "Fuite" boots enchantment dice).
  def character_dex_mastery
    character.dexterite + character.enchantment_dice("fuite")[0]
  end

  # Flee roll bonus: Esquive skill bonus + equipment flee_bonus (boots).
  def character_dex_bonus
    skill = character.skills.find_by(name: "Esquive")
    (skill ? skill.bonus : 0) + character.equipment_bonus("flee_bonus") + character.enchantment_dice("fuite")[1]
  end

  # ═══════════════════════════════════════════
  # Enchantments (config/catalog/enchantements.yml, EnchantmentService)
  # ═══════════════════════════════════════════

  ENCHANT_ELEMENTS = %w[feu eau lumiere nature ombre].freeze

  def weapon_enchantment
    return @weapon_enchantment if defined?(@weapon_enchantment)

    @weapon_enchantment = character.weapon_enchantment
  end

  def enchantment_dice(effect_key)
    @enchantment_dice ||= {}
    @enchantment_dice[effect_key] ||= character.enchantment_dice(effect_key)
  end

  # Elemental damage of an enchanted weapon, added after each landed weapon hit.
  # Magic damage: no resistance roll, but the target's elemental resistances apply.
  def weapon_enchantment_hit!(target)
    return if target[:hp] <= 0

    ench = weapon_enchantment
    return unless ench && ENCHANT_ELEMENTS.include?(ench[:key])

    roll = DiceRoller.roll(ench[:mastery], ench[:bonus])
    mod = apply_target_resistance(roll[:total], target, "magical", ench[:key])
    dmg = mod[:immune] ? 0 : [mod[:damage], 0].max
    target[:hp] = [target[:hp] - dmg, 0].max
    @log << "Enchantement (#{ench[:name].downcase}) : +#{dmg} dégâts à #{target[:name]} " \
            "(#{target[:hp]}/#{target[:max_hp]} PV)#{mod[:descriptor]}"
  end

  # "Clairvoyance" helmet enchantment: added to weapon and magic accuracy.
  def add_precision_enchantment(mastery, bonus)
    ench_m, ench_b = enchantment_dice("precision")
    [mastery + ench_m, bonus + ench_b]
  end

  # "Résistance magique" armor enchantment: % off enemy spell damage.
  def reduce_by_magic_resistance(damage)
    @magic_resistance ||= character.enchantment_percent("resistance_magique").clamp(0, 90)
    return damage if @magic_resistance.zero?

    reduced = (damage * (100 - @magic_resistance) / 100.0).round
    @log << "Résistance magique (#{@magic_resistance}%) : -#{damage - reduced} dégâts" if reduced < damage
    reduced
  end

  # "Épines" shield enchantment: hurts an enemy whose blow lands.
  def thorns_hit!(enemy)
    return if player_dead? || enemy[:hp] <= 0

    ench_m, ench_b = enchantment_dice("epines")
    return if (ench_m + ench_b).zero?

    dmg = DiceRoller.roll(ench_m, ench_b)[:total]
    enemy[:hp] = [enemy[:hp] - dmg, 0].max
    @log << "Épines : #{enemy[:name]} subit #{dmg} dégâts (#{enemy[:hp]}/#{enemy[:max_hp]} PV)"
    @log << "#{enemy[:name]} est vaincu !" if enemy[:hp] <= 0
  end

  # "Régénération" (armor) and "Méditation" (helmet): end of round recovery.
  def tick_player_enchantments
    player = @state[:player]
    regen_m, regen_b = enchantment_dice("regeneration")
    if (regen_m + regen_b).positive? && player[:hp] < player[:max_hp]
      heal = [DiceRoller.roll(regen_m, regen_b)[:total], player[:max_hp] - player[:hp]].min
      player[:hp] += heal
      @log << "Régénération : +#{heal} PV (#{player[:hp]}/#{player[:max_hp]})"
    end

    med_m, med_b = enchantment_dice("meditation")
    return unless (med_m + med_b).positive? && player[:mana].to_i < player[:max_mana].to_i

    mana = [DiceRoller.roll(med_m, med_b)[:total], player[:max_mana] - player[:mana]].min
    player[:mana] += mana
    @log << "Méditation : vous récupérez #{mana} mana (#{player[:mana]}/#{player[:max_mana]})"
  end

  # Every equipped weapon/armor piece loses durability at the end of a fight
  # (-1, or -10 on a defeat). At 0 it is unequipped. Repaired at the forge (ForgeController#repair).
  def wear_equipment!(result)
    amount = result == :defeat ? InventoryItem::WEAR_PER_DEFEAT : InventoryItem::WEAR_PER_FIGHT
    worn = character.inventory_items.where(equipped: true, item_type: "equipment").where("durability > 0").to_a
    return if worn.empty?

    worn.each { |item| item.wear!(amount) }
    # A broken item (0) is unequipped: back in the bag, no effect until repaired.
    broken = worn.select { |item| item.durability.zero? }
    broken.each { |item| item.update!(equipped: false) }
    message = "Usure de l'équipement : -#{amount} durabilité"
    if broken.any?
      message += " (hors d'usage et retiré#{'s' if broken.size > 1} : #{broken.map(&:display_name).join(', ')})"
    end
    @state[:log] << message
  end

  # Tower bosses always drop soul stones; every other defeated monster has a chance.
  def soul_stones_reward
    cfg = GameCatalog.enchantments_data["soul_stones"] || {}
    floor = @state[:floor].to_i
    boss = floor.positive? && GameCatalog.floor(floor)&.dig("boss")
    stones = boss ? cfg["boss_base"].to_i + (floor / [cfg["boss_floors_step"].to_i, 1].max) : 0
    others = boss ? @state[:enemies].size - 1 : @state[:enemies].size
    stones + others.times.count { rand(100) < soul_stone_drop_chance(cfg) }
  end

  # ═══════════════════════════════════════════
  # Tower loot (config/catalog/butin.yml)
  # ═══════════════════════════════════════════

  # Rolls the loot of a tower victory from the Fouille roll total and adds it
  # to the inventory. Returns a list of { key, name, tier, item_type } (maybe empty):
  # a great roll gives a second item, never a better tier.
  def resolve_tower_loot(fouille_total)
    cfg = GameCatalog.loot_data
    floor = @state[:floor].to_i
    boss = GameCatalog.floor(floor)&.dig("boss").present?

    chance = loot_find_chance(cfg, fouille_total)
    chance = [chance + cfg["boss_chance_bonus"].to_i, 100].min if boss && chance.positive?
    return [] unless rand(100) < chance

    count = fouille_total >= loot_difficulty(floor) + cfg["great_margin"].to_i ? 2 : 1
    tier = loot_tier(cfg, floor, fouille_total, boss)
    equipment_chance = (boss ? cfg["boss_equipment_chance"] : cfg["equipment_chance"]).to_i

    Array.new(count) do
      item_type = rand(100) < equipment_chance ? "equipment" : "item"
      data = pick_loot(item_type, tier)
      next unless data

      add_loot_to_inventory(data, item_type)
      { key: data["key"], name: data["name"], tier: data["tier"], item_type: item_type }
    end.compact
  end

  def loot_find_chance(cfg, total)
    row = (cfg["find_chance"] || []).select { |r| total >= r["min_roll"].to_i }.max_by { |r| r["min_roll"].to_i }
    row ? row["chance"].to_i : 0
  end

  # The floor sets the tier (hard cap), +1 on a boss floor, −1 on a weak roll.
  def loot_tier(cfg, floor, total, boss)
    tier = 1 + ([floor, 1].max - 1) / [cfg["floors_per_tier"].to_i, 1].max
    tier += cfg["boss_tier_bonus"].to_i if boss
    tier -= 1 if total < loot_difficulty(floor)
    [tier, 1].max
  end

  def loot_difficulty(floor)
    5 + floor / 5
  end

  # A random entry of that tier, or of the highest lower tier available.
  def pick_loot(item_type, tier)
    pool = GameCatalog.loot_pool(item_type)
    best = pool.map { |d| d["tier"].to_i }.select { |t| t <= tier }.max
    best && pool.select { |d| d["tier"].to_i == best }.sample
  end

  def add_loot_to_inventory(data, item_type)
    existing = item_type == "item" && character.inventory_items.find_by(item_key: data["key"], item_type: "item", equipped: false)
    if existing
      existing.update!(quantity: existing.quantity + 1)
    else
      character.inventory_items.create!(item_key: data["key"], item_type: item_type, quantity: 1,
                                        equipped: false, slot: item_type == "equipment" ? data["slot"] : nil)
    end
  end

  def loot_messages(loot)
    return ["Butin : rien d'autre à récupérer."] if loot.blank?

    loot.map { |l| "Butin : vous trouvez #{l[:name]} (T#{l[:tier]}) !" }
  end

  # % chance per defeated monster to drop a soul stone, from the Fouille skill:
  # drop_chance_min at 1D, + drop_chance_per_step per skill upgrade, capped at drop_chance_max.
  def soul_stone_drop_chance(cfg = GameCatalog.enchantments_data["soul_stones"] || {})
    self.class.soul_stone_drop_chance(character, cfg)
  end

  def self.soul_stone_drop_chance(character, cfg = GameCatalog.enchantments_data["soul_stones"] || {})
    skill = character.skills.find_by(name: "Fouille")
    steps = skill ? (skill.mastery - 1) * 3 + skill.bonus : 0
    min = cfg.fetch("drop_chance_min", 5).to_i
    max = cfg.fetch("drop_chance_max", 50).to_i
    (min + steps * cfg.fetch("drop_chance_per_step", 2).to_i).clamp(min, max)
  end

  # ═══════════════════════════════════════════
  # Combat end
  # ═══════════════════════════════════════════

  def finish_combat(result)
    @state[:status] = result.to_s
    log_start = @state[:log].size
    rewards = {}

    tower_combat = @state[:floor].to_i.positive?

    case result
    when :victory
      base_xp = @state[:enemies].sum { |e| e[:xp_value].to_i }
      base_gold = @state[:enemies].sum { |e| e[:gold_value].to_i }

      if tower_combat
        xp_reward = (base_xp / 2.0).ceil
        search = resolve_search_loot(base_gold)
        gold_reward = search[:gold]
        loot = resolve_tower_loot(search[:roll])
      else
        xp_reward = base_xp
        gold_reward = base_gold
        search = nil
      end
      stones = soul_stones_reward

      character.update!(
        xp: character.xp + xp_reward,
        gold: character.gold + gold_reward,
        soul_stones: character.soul_stones + stones,
        current_hp: [@state[:player][:hp], 1].max,
        current_mana: @state[:player][:mana],
        current_floor: [@state[:floor], character.current_floor].max,
        combat_state: nil
      )
      character.advance_day unless tower_combat

      @state[:log].concat(@log)
      @state[:log] << search[:message] if search
      @state[:log].concat(loot_messages(loot)) if search
      stones_text = stones.positive? ? ", +#{stones} pierre#{'s' if stones > 1} d'âme" : ""
      @state[:log] << "Victoire ! +#{xp_reward} XP, +#{gold_reward} or#{stones_text}."
      rewards = { xp: xp_reward, gold: gold_reward, soul_stones: stones }
      rewards[:loot] = loot if loot.present?

      CombatLog.create!(character: character, floor: @state[:floor], result: "victory",
                         xp_gained: xp_reward, gold_gained: gold_reward,
                         log_data: @state[:log].last(50))
    when :defeat
      character.update!(
        current_hp: 1,
        current_mana: [(@state[:player][:mana] || 0), 0].max,
        combat_state: nil
      )
      character.update!(tower_session_active: false) if tower_combat

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
      character.advance_day unless tower_combat

      @state[:log].concat(@log) if @log.any?

      CombatLog.create!(character: character, floor: @state[:floor], result: "fled",
                         log_data: @state[:log].last(50))
    end

    wear_equipment!(result)

    {
      floor: @state[:floor],
      turn: @state[:turn],
      status: @state[:status],
      player: {
        hp: character.current_hp,
        max_hp: character.max_hp,
        mana: character.current_mana,
        max_mana: character.max_mana,
        statuses: [],
        defense: self.class.defense_info(character),
        initiative: @state[:player_initiative]
      },
      enemies: (@state[:enemies] || []).map.with_index { |e, i|
        { index: i, key: e[:key], name: e[:name], hp: e[:hp], max_hp: e[:max_hp], alive: e[:hp] > 0, statuses: e[:statuses] || [], revealed_resistances: revealed_resistances_for(e) }
      },
      log: @state[:log].last(20),
      recent_log: @state[:log][log_start..],
      rewards: rewards
    }
  end

  def save_state!
    character.update!(combat_state: @state.deep_stringify_keys)
  end

  def resolve_search_loot(base_gold)
    skill = character.skills.find_by(name: "Fouille")
    mastery = skill&.mastery || 1
    bonus = skill&.bonus || 0
    roll = DiceRoller.roll(mastery, bonus)
    total = roll[:total]
    tier = total / 5
    multiplier = tier < 1 ? 0.0 : 0.75 + 0.25 * (tier - 1)
    gold = (base_gold * multiplier).floor

    notation = DiceRoller.notation(mastery, bonus)
    descriptor = case
                 when total < 5 then "vous ne trouvez rien"
                 when total < 10 then "vous trouvez quelques pièces"
                 when total < 15 then "fouille standard"
                 when total < 20 then "bonne fouille"
                 when total < 25 then "fouille minutieuse"
                 else "trésor exceptionnel"
                 end
    { gold: gold, roll: total, multiplier: multiplier,
      message: "Fouille (#{notation}) : #{total} — #{descriptor} (pierres d'âme : #{soul_stone_drop_chance}% par monstre)." }
  end
end
