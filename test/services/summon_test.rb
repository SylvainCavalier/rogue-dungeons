require "test_helper"
require "minitest/mock"

class SummonTest < ActiveSupport::TestCase
  MISS = { hit: false, graze: false, attack: { total: 1 }, defense: { total: 20 }, margin: -19 }.freeze
  HIT = { hit: true, graze: false, attack: { total: 20 }, defense: { total: 1 }, margin: 19 }.freeze

  setup do
    user = User.create!(email: "summon-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Invocateur", vigueur: 2, dexterite: 2, intelligence: 4,
                                        charisme: 2, perception: 2)
    GameCatalog.magics_for_element("invocation").each do |m|
      @character.learned_magics.create!(magic_key: m["key"], name: m["name"], element: "invocation", tier: m["tier"])
    end
  end

  def enemy(name, hp: 50, damage: 3, initiative: 1)
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: hp, max_hp: hp, vigueur: stat, attack: stat,
      damage: { mastery: damage, bonus: 0 }, esquive: stat, dr: { mastery: 0, bonus: 0 }, vitesse: stat,
      xp_value: 1, gold_value: 1, abilities: [], ability_chance: 0, resistances: {}, statuses: [], debuffs: {},
      initiative: initiative }
  end

  def fight(enemies, hp: 30)
    @character.update!(combat_state: {
      floor: 1, turn: 1, player: { hp: hp, max_hp: 30, mana: 60, max_mana: 60 },
      enemies: enemies, log: [], status: "active", player_statuses: [], player_debuffs: {},
      player_initiative: 10
    })
    CombatService.new(@character.reload)
  end

  def next_turn(stub, type = "item", key = nil)
    DiceRoller.stub(:opposed_roll, stub) { CombatService.new(@character.reload).player_action(type, key: key, item_id: 0) }
  end

  test "every summon spell points to a creature" do
    GameCatalog.magics_for_element("invocation").each do |m|
      assert GameCatalog.summon(GameCatalog.magic_data(m["key"])["summon"]), m["key"]
    end
  end

  test "the Invocation skill exists and sets the creature's strength" do
    assert @character.skills.exists?(name: "Invocation")
    fight([enemy("A")])
    result = next_turn(MISS, "magic", "golem_d_argile")
    golem = result[:allies].first
    data = GameCatalog.summon("golem_d_argile")
    assert_equal data["hp"] + data["hp_per_die"] * 3, golem[:max_hp], "Invocation 4D = 3 dice above 1"
    assert_equal data["attack"]["mastery"] + 1, @character.reload.combat_state["allies"].first["attack"]["mastery"]
  end

  test "a new summon replaces the previous one" do
    fight([enemy("A")])
    next_turn(MISS, "magic", "familier")
    result = next_turn(MISS, "magic", "loup_spectral")
    assert_equal ["Loup spectral"], result[:allies].map { |a| a[:name] }
    assert(result[:recent_log].any? { |l| l.include?("Familier retourne") })
  end

  test "the creature acts from the turn after it was summoned" do
    fight([enemy("A", hp: 500)])
    result = next_turn(MISS, "magic", "loup_spectral")
    assert_not(result[:recent_log].any? { |l| l.start_with?("Loup spectral attaque") })

    result = next_turn(HIT)
    assert(result[:recent_log].any? { |l| l.start_with?("Loup spectral attaque A") }, result[:recent_log].inspect)
    assert result[:enemies].first[:hp] < 500
  end

  test "enemies aim at the creature according to its taunt, and the player is spared" do
    fight([enemy("A")])
    next_turn(MISS, "magic", "golem_d_argile")
    state = @character.reload.combat_state
    state["allies"].first["taunt"] = 100
    state["enemies"].first["intent"] = { "ability" => nil, "target" => 0 }
    @character.update!(combat_state: state)

    result = next_turn(HIT)
    assert_equal 30, result[:player][:hp]
    assert result[:allies].first[:hp] < result[:allies].first[:max_hp]
    assert(result[:recent_log].any? { |l| l.start_with?("A attaque Golem d'argile") })
  end

  test "Intuition shows which creature an enemy aims at" do
    service = fight([enemy("A")])
    service.state[:allies] = [{ name: "Golem d'argile", hp: 10, max_hp: 10 }]
    assert_equal "attaque (vise Golem d'argile)", service.send(:intent_label, { ability: nil, target: 0 })
    assert_equal "attaque", service.send(:intent_label, { ability: nil, target: nil })
  end

  test "a destroyed creature stops acting, the Phénix comes back once" do
    service = fight([enemy("A")])
    service.send(:resolve_magic_summon, GameCatalog.magic_data("phenix"))
    phoenix = service.state[:allies].first
    service.send(:hurt_ally!, phoenix, 999, "coup")
    assert_equal (phoenix[:max_hp] / 2.0).ceil, phoenix[:hp]
    service.send(:hurt_ally!, phoenix, 999, "coup")
    assert_equal 0, phoenix[:hp]
    assert_empty service.send(:living_allies)
  end

  test "the Esprit gardien heals the player every turn" do
    fight([enemy("A")], hp: 10)
    next_turn(MISS, "magic", "esprit_gardien")
    result = next_turn(MISS)
    assert result[:player][:hp] > 10
    assert(result[:recent_log].any? { |l| l.start_with?("Esprit gardien vous soigne") })
  end

  test "a full fight with a summon runs to the end" do
    @character.update!(combat_state: nil, current_mana: 60, bonus_max_mana: 50)
    result = CombatService.new(@character.reload).start_combat(5)
    result = CombatService.new(@character.reload).player_action("magic", key: "gardien_de_pierre")
    40.times do
      break unless result[:status] == "active"
      result = CombatService.new(@character.reload).player_action("attack", target: 0)
    end
    assert_includes %w[active victory defeat], result[:status]
  end

  def learn_necromancy
    m = GameCatalog.magic("necromancie")
    @character.learned_magics.create!(magic_key: "necromancie", name: m["name"], element: "ombre", tier: m["tier"])
  end

  # Ombre skill set to 99D in these tests: its roll returns `total`, other rolls their average.
  def roll_ombre(total, &block)
    roll = ->(mastery, bonus = 0) { { total: mastery == 99 ? total : [mastery, 0].max * 3 + bonus, rolls: [], bonus: bonus, mastery: mastery } }
    DiceRoller.stub(:roll, roll, &block)
  end

  test "Nécromancie is the tier 6 Ombre magic, Terreur nocturne stays for monsters" do
    assert_equal 6, GameCatalog.magic("necromancie")["tier"]
    assert_nil GameCatalog.magic("terreur_nocturne")
    assert GameCatalog.magic_data("terreur_nocturne")
  end

  test "Nécromancie is refused without a corpse, without spending mana or the turn" do
    learn_necromancy
    result = fight([enemy("A")]).player_action("magic", key: "necromancie")
    assert_match "Aucun ennemi tombé", result[:error]
    assert_equal 60, @character.reload.combat_state["player"]["mana"]
  end

  test "Nécromancie raises the strongest fallen enemy, graded by the Ombre roll" do
    learn_necromancy
    @character.skills.find_by(name: "Ombre").update!(mastery: 99, bonus: 0)
    weak = enemy("Faible", hp: 10).merge(hp: 0)
    strong = enemy("Fort", hp: 40).merge(hp: 0, attack: { mastery: 2, bonus: 0 })
    service = fight([weak, strong, enemy("Vivant")])
    # difficulty = 5 + 2 × 2 = 9; 9 + 10 = éclatante (100% PV, +1D)
    result = roll_ombre(19) { DiceRoller.stub(:opposed_roll, MISS) { service.player_action("magic", key: "necromancie") } }
    undead = result[:allies].first
    assert_equal "Fort (mort-vivant)", undead[:name]
    assert undead[:undead]
    assert_equal "monsters", undead[:image_dir]
    assert_equal 40, undead[:max_hp]
    assert_equal 4, @character.reload.combat_state["allies"].first["damage"]["mastery"], "3D + 1D"
    assert @character.combat_state["enemies"][1]["raised"]
  end

  test "a weak Nécromancie roll gives a weaker undead, a failure crumbles the corpse" do
    learn_necromancy
    @character.skills.find_by(name: "Ombre").update!(mastery: 99, bonus: 0)
    service = fight([enemy("Mort", hp: 40).merge(hp: 0, damage: { mastery: 3, bonus: 0 }), enemy("Vivant")])
    result = roll_ombre(8) { DiceRoller.stub(:opposed_roll, MISS) { service.player_action("magic", key: "necromancie") } }
    assert_equal 20, result[:allies].first[:max_hp], "difficulty 7, margin 1: 50% PV"
    assert_equal 2, @character.reload.combat_state["allies"].first["damage"]["mastery"]

    service = fight([enemy("Mort", hp: 40).merge(hp: 0), enemy("Vivant")])
    result = roll_ombre(2) { DiceRoller.stub(:opposed_roll, MISS) { service.player_action("magic", key: "necromancie") } }
    assert_empty result[:allies]
    assert(result[:recent_log].any? { |l| l.include?("se désagrège") })
    assert_match "Aucun ennemi tombé", CombatService.new(@character.reload).player_action("magic", key: "necromancie")[:error]
  end

  test "bosses can't be raised" do
    learn_necromancy
    enemies = MonsterFactory.build_for_floor(10)
    assert_equal 1, enemies.count { |e| e[:boss] }
    boss = enemies.find { |e| e[:boss] }.merge(hp: 0)
    result = fight([boss, enemy("Vivant")]).player_action("magic", key: "necromancie")
    assert_match "boss", result[:error]
  end
end
