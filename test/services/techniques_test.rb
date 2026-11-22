require "test_helper"
require "minitest/mock"

class TechniquesTest < ActiveSupport::TestCase
  MISS = { hit: false, graze: false, attack: { total: 1 }, defense: { total: 20 }, margin: -19 }.freeze
  HIT = { hit: true, graze: false, attack: { total: 20 }, defense: { total: 1 }, margin: 19 }.freeze

  setup do
    user = User.create!(email: "tech-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
  end

  def learn(*keys)
    keys.each do |key|
      tech = GameCatalog.technique(key)
      @character.learned_techniques.create!(technique_key: key, name: tech["name"], category: tech["category"])
    end
  end

  def enemy(name, hp: 50, damage: 1, initiative: 1)
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: hp, max_hp: hp, vigueur: stat, attack: stat,
      damage: { mastery: damage, bonus: 0 }, esquive: stat, dr: { mastery: 0, bonus: 0 }, vitesse: stat,
      xp_value: 1, gold_value: 1, abilities: [], ability_chance: 0, resistances: {}, statuses: [], debuffs: {},
      initiative: initiative }
  end

  def fight(enemies, hp: 30, extra: {})
    @character.update!(combat_state: {
      floor: 1, turn: 1, player: { hp: hp, max_hp: 30, mana: 6, max_mana: 6 },
      enemies: enemies, log: [], status: "active", player_statuses: [], player_debuffs: {},
      player_initiative: 10
    }.merge(extra))
    CombatService.new(@character.reload)
  end

  test "every guild technique has mechanics, a valid prerequisite and passives a passive key" do
    GameCatalog.all_techniques.each do |t|
      data = GameCatalog.technique_data(t["key"])
      assert data, "#{t['key']} missing from techniques.yml"
      assert_equal t["category"], data["category"], t["key"]
      assert GameCatalog.technique(data["requires"]), "#{t['key']} requires an unknown technique" if data["requires"]
      assert data["passive"].present?, t["key"] if t["category"] == "passive"
    end
    assert(GameCatalog.techniques_for_category("advanced").all? { |t| GameCatalog.technique_data(t["key"])["requires"] })
  end

  test "advanced techniques need their prerequisite at the guild" do
    @character.update!(warrior_rank: 3)
    result = GuildService.new(@character).start("frappe_transcendante")
    assert_not result[:success]
    assert_match "Coup chargé", result[:error]

    learn("coup_charge")
    assert GuildService.new(@character.reload).start("frappe_transcendante")[:success]
  end

  test "a technique goes on cooldown and can't be used again until it recharges" do
    learn("coup_charge")
    result = fight([enemy("Cible", hp: 200)]).player_action("technique", key: "coup_charge")
    assert_equal 2, result[:player][:technique_cooldowns]["coup_charge"]

    refused = CombatService.new(@character.reload).player_action("technique", key: "coup_charge")
    assert_match "recharge", refused[:error]
    assert_equal 2, @character.reload.combat_state["turn"], "a refused technique doesn't spend the turn"

    2.times { CombatService.new(@character.reload).player_action("item", item_id: 0) }
    result = CombatService.new(@character.reload).player_action("technique", key: "coup_charge")
    assert_nil result[:error]
  end

  test "passive techniques can't be used as an action" do
    learn("survie")
    assert_match "passive", fight([enemy("Cible")]).player_action("technique", key: "survie")[:error]
  end

  test "Contre-attaque counters every dodged blow and no longer cancels a hit" do
    learn("contre_attaque")
    service = fight([enemy("A"), enemy("B")])
    result = DiceRoller.stub(:opposed_roll, MISS) { service.player_action("technique", key: "contre_attaque") }
    assert_equal 2, result[:recent_log].count { |l| l.start_with?("Contre-attaque !") }

    service = fight([enemy("A")])
    service.state[:player_counter] = { counter_damage_bonus: 0 }
    DiceRoller.stub(:opposed_roll, HIT) { service.send(:resolve_enemy_attack, service.state[:enemies].first) }
    assert service.state[:player][:hp] < 30, "a landed blow still deals damage"
    assert_not(service.log.any? { |l| l.start_with?("Contre-attaque") })
  end

  test "Riposte counters only the first parried blow of each round" do
    learn("riposte")
    @character.update!(defense_mode: "parade")
    service = fight([enemy("A"), enemy("B"), enemy("C")])
    result = DiceRoller.stub(:opposed_roll, MISS) { service.player_action("item", item_id: 0) }
    header = result[:recent_log].index { |l| l.start_with?("--- Tour") }
    assert_equal 1, result[:recent_log][0...header].count { |l| l.start_with?("Riposte !") }
  end

  test "Riposte does nothing in dodge mode" do
    learn("riposte")
    service = fight([enemy("A")])
    result = DiceRoller.stub(:opposed_roll, MISS) { service.player_action("item", item_id: 0) }
    assert_not(result[:recent_log].any? { |l| l.start_with?("Riposte") })
  end

  test "Survie saves the player at 1 PV once per fight" do
    learn("survie")
    service = fight([enemy("A", damage: 40), enemy("B", damage: 40)], hp: 10)
    result = DiceRoller.stub(:opposed_roll, HIT) { service.player_action("item", item_id: 0) }
    assert_equal 1, result[:recent_log].count { |l| l.start_with?("Survie") }
    assert_equal "defeat", result[:status], "the second blow of the round kills: Survie works once"
  end

  test "Survie keeps the player alive after a single killing blow" do
    learn("survie")
    service = fight([enemy("A", damage: 40)], hp: 10)
    result = DiceRoller.stub(:opposed_roll, HIT) { service.player_action("item", item_id: 0) }
    assert_equal "active", result[:status]
    assert_equal 1, result[:player][:hp]
  end

  test "Instinct du vétéran delays the several-attackers penalty to the third attack" do
    learn("instinct_du_veteran")
    service = fight([enemy("A"), enemy("B"), enemy("C")])
    result = DiceRoller.stub(:opposed_roll, MISS) { service.player_action("item", item_id: 0) }
    penalties = result[:recent_log].select { |l| l.include?("affaiblie") }
    assert_equal ["-1D, attaque n°3"], penalties.map { |l| l[/-\dD, attaque n°\d/] }
  end

  test "Rage du désespoir adds a damage die under 30% PV" do
    learn("rage_du_desespoir")
    service = fight([enemy("A")], hp: 30)
    full = service.send(:player_damage, nil)
    service.state[:player][:hp] = 5
    assert_equal full[0] + 1, service.send(:player_damage, nil)[0]
  end

  test "enemy statuses from techniques now change its dice" do
    service = fight([enemy("A", damage: 3)])
    target = service.state[:enemies].first
    base_damage = service.send(:enemy_damage_dice, target)[0]
    base_defense = service.send(:enemy_defense, target.merge(esquive: { mastery: 3, bonus: 0 }))[0]

    target[:statuses] = [{ name: "Affaibli", remaining: 3 }]
    assert_equal base_damage - 1, service.send(:enemy_damage_dice, target)[0]

    target[:statuses] = [{ name: "Enragé", remaining: 3 }]
    assert_equal base_damage + 1, service.send(:enemy_damage_dice, target)[0]

    target[:statuses] = [{ name: "Garde brisée", remaining: 3 }]
    assert_equal base_defense - 1, service.send(:enemy_defense, target.merge(esquive: { mastery: 3, bonus: 0 }))[0]

    target[:statuses] = [{ name: "Désarmé", remaining: 3 }]
    att = service.send(:apply_enemy_status_mods_attack, target.merge(attack: { mastery: 3, bonus: 0 }), 3, 0)
    assert_equal 2, att[:mastery]
  end

  test "Frappe transcendante always hits" do
    learn("coup_charge", "frappe_transcendante")
    service = fight([enemy("A", hp: 200)])
    result = DiceRoller.stub(:opposed_roll, MISS) { service.player_action("technique", key: "frappe_transcendante") }
    assert(result[:recent_log].any? { |l| l.start_with?("Frappe transcendante sur A : touché") }, result[:recent_log].inspect)
  end

  test "stances add defense or resistance dice" do
    learn("posture_defensive", "mur_d_acier")
    service = fight([enemy("A")])
    base_def = service.send(:player_defense_vs, nil)[0]
    base_res = service.send(:player_resistance_dice)[0]
    service.send(:resolve_stance, GameCatalog.technique_data("posture_defensive"))
    assert_equal base_def + 2, service.send(:player_defense_vs, nil)[0]
    service.send(:resolve_stance, GameCatalog.technique_data("mur_d_acier"))
    assert_equal base_res + 2, service.send(:player_resistance_dice)[0]
  end

  test "every guild technique resolves in a real fight" do
    keys = GameCatalog.all_techniques.reject { |t| t["category"] == "passive" }.map { |t| t["key"] }
    learn(*keys)
    keys.each do |key|
      @character.update!(combat_state: nil, current_hp: @character.max_hp)
      CombatService.new(@character).start_combat(1)
      result = CombatService.new(@character.reload).player_action("technique", key: key)
      assert_nil result[:error], key
      assert_not(result[:recent_log].to_a.any? { |l| l.include?("inconnue") || l.include?("non implémenté") }, key)
    end
  end
end
