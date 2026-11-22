require "test_helper"
require "minitest/mock"

class MagicTest < ActiveSupport::TestCase
  MISS = { hit: false, graze: false, attack: { total: 1 }, defense: { total: 20 }, margin: -19 }.freeze
  HIT = { hit: true, graze: false, attack: { total: 20 }, defense: { total: 1 }, margin: 19 }.freeze

  setup do
    user = User.create!(email: "magic-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Mage", vigueur: 2, dexterite: 2, intelligence: 4,
                                        charisme: 2, perception: 2)
  end

  def learn(*keys)
    keys.each do |key|
      magic = GameCatalog.magic(key)
      @character.learned_magics.create!(magic_key: key, name: magic["name"], element: magic["element"], tier: magic["tier"])
    end
  end

  def enemy(name, hp: 50, initiative: 1, resistances: {}, attack: 1, abilities: [])
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: hp, max_hp: hp, vigueur: stat, attack: { mastery: attack, bonus: 0 },
      damage: stat, esquive: stat, dr: { mastery: 0, bonus: 0 }, vitesse: stat, xp_value: 1, gold_value: 1,
      abilities: abilities, ability_chance: 0, resistances: resistances, statuses: [], debuffs: {},
      initiative: initiative }
  end

  def fight(enemies, hp: 30, extra: {})
    @character.update!(combat_state: {
      floor: 1, turn: 1, player: { hp: hp, max_hp: 30, mana: 40, max_mana: 40 },
      enemies: enemies, log: [], status: "active", player_statuses: [], player_debuffs: {},
      player_initiative: 10
    }.merge(extra))
    CombatService.new(@character.reload)
  end

  def act(service, stub, type, key)
    DiceRoller.stub(:opposed_roll, stub) { service.player_action(type, key: key, item_id: 0) }
  end

  test "magies.md and magies.yml agree, and every status they use exists" do
    md = GameCatalog.all_magics
    assert_empty md.map { |m| m["key"] } - GameCatalog.all_magics_data.keys, "academy magics need mechanics"
    md.each do |m|
      data = GameCatalog.magic_data(m["key"])
      assert_equal [m["element"], m["tier"]], [data["element"], data["tier"]], m["key"]
      statuses = [data["inflict_status"], *Array(data["buff_statuses"] || data["buff_status"])].compact
      statuses.each { |s| assert GameCatalog.all_statuses_data[s], "#{m['key']}: unknown status #{s}" }
    end
  end

  test "every academy magic resolves in a real fight" do
    keys = GameCatalog.all_magics.map { |m| m["key"] }
    learn(*keys)
    keys.each do |key|
      @character.update!(combat_state: nil, current_hp: @character.max_hp, current_mana: 99, bonus_max_mana: 90)
      CombatService.new(@character.reload).start_combat(1)
      result = CombatService.new(@character.reload).player_action("magic", key: key)
      assert_not(result[:recent_log].to_a.any? { |l| l.include?("non implémenté") || l.include?("inconnue") }, key)
    end
  end

  test "status spells need to hit and respect element immunities" do
    learn("cecite")
    result = act(fight([enemy("A")]), MISS, "magic", "cecite")
    assert_empty result[:enemies].first[:statuses]

    result = act(fight([enemy("A")]), HIT, "magic", "cecite")
    assert_equal ["Aveuglé"], result[:enemies].first[:statuses].map { |s| s[:name] }

    result = act(fight([enemy("Spectre", resistances: { ombre: 100 })]), HIT, "magic", "cecite")
    assert_empty result[:enemies].first[:statuses]
    assert(result[:recent_log].any? { |l| l.include?("immunisé") })
  end

  test "a 1-round stun makes a faster enemy lose its next turn" do
    learn("racines_entravantes")
    service = fight([enemy("Rapide", initiative: 20)])
    service.state[:enemies].first[:statuses] = []
    # Étourdi applied during the player's turn must survive until the faster enemy acts.
    service.send(:apply_status_to_enemy, service.state[:enemies].first, "Étourdi", 1)
    result = act(service, MISS, "item", nil)
    after_header = result[:recent_log].drop_while { |l| !l.start_with?("--- Tour") }
    assert(after_header.any? { |l| l.include?("Rapide est étourdi") }, result[:recent_log].inspect)
    assert_empty result[:enemies].first[:statuses], "the stun is spent after its turn"
  end

  test "a 1-round stun from a slower enemy costs the player their next turn" do
    service = fight([enemy("Lent", attack: 40, abilities: ["etourdissement"]).merge(intent: { ability: "etourdissement" })])
    result = act(service, HIT, "item", nil)
    assert_equal ["Étourdi"], result[:player][:statuses].map { |s| s[:name] }, result[:recent_log].inspect

    result = act(CombatService.new(@character.reload), MISS, "item", nil)
    assert(result[:recent_log].any? { |l| l.include?("étourdi et perdez votre tour") })
  end

  test "Pas dans l'ombre makes the next attack hit even a turn later" do
    learn("pas_dans_l_ombre")
    service = fight([enemy("A", hp: 200)])
    act(service, MISS, "magic", "pas_dans_l_ombre")
    assert_equal ["Invisible"], @character.reload.combat_state["player_statuses"].map { |s| s["name"] }

    result = DiceRoller.stub(:opposed_roll, ->(a, *_rest) { a >= 99 ? HIT : MISS }) do
      CombatService.new(@character.reload).player_action("attack", target: 0)
    end
    assert result[:enemies].first[:hp] < 200, result[:recent_log].inspect
  end

  test "self buffs last their full duration" do
    learn("bouclier_lumineux")
    result = act(fight([enemy("A")]), MISS, "magic", "bouclier_lumineux")
    assert_equal({ "Protégé" => 3, "Béni" => 3 }, result[:player][:statuses].to_h { |s| [s[:name], s[:remaining]] })

    result = act(CombatService.new(@character.reload), MISS, "item", nil)
    assert_equal({ "Protégé" => 2, "Béni" => 2 }, result[:player][:statuses].to_h { |s| [s[:name], s[:remaining]] })
  end

  test "Maudit lowers resistances but keeps immunities" do
    service = fight([enemy("A")])
    target = { resistances: { feu: 100 }, statuses: [{ name: "Maudit", remaining: 3 }] }
    assert_equal 0, service.send(:apply_target_resistance, 20, target, "magical", "feu")[:damage]
    target[:resistances] = {}
    assert_equal 25, service.send(:apply_target_resistance, 20, target, "physical")[:damage]
    target[:resistances] = { physical: 50 }
    assert_equal 15, service.send(:apply_target_resistance, 20, target, "physical")[:damage]
  end

  test "damage spells gain +1 per 2 dice of the element skill" do
    assert_equal 2, @character.spell_power("feu")
    @character.skills.find_by(name: "Feu").update!(mastery: 7)
    assert_equal 3, @character.reload.spell_power("feu")

    learn("etincelle")
    result = act(fight([enemy("A", hp: 200)]), HIT, "magic", "etincelle")
    dealt = 200 - result[:enemies].first[:hp]
    assert dealt >= 1 + 2 + 3, "1D+2 plus 3 of spell power: #{dealt}"
  end

  test "Lumière vitale heals half of the max PV" do
    learn("lumiere_vitale")
    result = act(fight([enemy("A")], hp: 5), MISS, "magic", "lumiere_vitale")
    assert_equal 20, result[:player][:hp]
  end
end
