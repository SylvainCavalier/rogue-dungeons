require "test_helper"

class CombatItemsTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "items-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
  end

  def enemy(name, hp: 50, initiative: 1)
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: hp, max_hp: hp, vigueur: stat, attack: stat, damage: stat, esquive: stat,
      dr: { mastery: 0, bonus: 0 }, vitesse: stat, xp_value: 1, gold_value: 1, abilities: [],
      resistances: {}, statuses: [], debuffs: {}, initiative: initiative }
  end

  def fight(enemies, floor: 1, statuses: [])
    @character.update!(combat_state: {
      floor: floor, turn: 1, player: { hp: 200, max_hp: 200, mana: 6, max_mana: 6 },
      enemies: enemies, log: [], status: "active", player_statuses: statuses, player_debuffs: {},
      player_initiative: 10
    })
    CombatService.new(@character)
  end

  def give(key, quantity = 1)
    @character.inventory_items.create!(item_key: key, item_type: "item", quantity: quantity)
  end

  def use(service, item)
    service.player_action("item", item_id: item.id)
  end

  test "the explosive vial hits every enemy" do
    result = use(fight([enemy("A"), enemy("B")]), give("explosive_vial"))
    assert(result[:enemies].all? { |e| e[:hp] < 50 })
  end

  test "the blinding bomb blinds every enemy" do
    result = use(fight([enemy("A"), enemy("B")]), give("blinding_bomb"))
    assert(result[:enemies].all? { |e| e[:statuses].any? { |s| s[:name] == "Aveuglé" } })
  end

  test "combat elixirs apply a positive status" do
    result = use(fight([enemy("A")]), give("elixir_vigor"))
    assert_includes result[:player][:statuses].map { |s| s[:name] }, "Protégé"
  end

  test "smelling salts remove mental statuses only" do
    service = fight([enemy("A")], statuses: [{ name: "Terrorisé", remaining: 2 }, { name: "Brûlé", remaining: 2 }])
    service.send(:resolve_item, give("smelling_salts").id)
    assert_equal ["Brûlé"], service.state[:player_statuses].map { |s| s[:name] }
  end

  test "the smoke bomb flees a normal fight" do
    result = use(fight([enemy("A")], floor: 3), give("smoke_bomb"))
    assert_equal "fled", result[:status]
    assert_not @character.inventory_items.exists?(item_key: "smoke_bomb")
  end

  test "the smoke bomb fails against a boss and is kept, the teleport stone works" do
    smoke = give("smoke_bomb")
    result = use(fight([enemy("Boss")], floor: 10), smoke)
    assert_equal "active", result[:status]
    assert smoke.reload.persisted?

    result = use(CombatService.new(@character.reload), give("teleport_stone"))
    assert_equal "fled", result[:status]
  end

  test "escape items don't work during a siege" do
    result = use(fight([enemy("A")], floor: 0), give("teleport_stone"))
    assert_equal "active", result[:status]
  end

  test "the enchanted compass prevents the opening ambush" do
    give("compass_enchanted")
    @character.skills.find_by!(name: "Vitesse").update!(mastery: 1)
    state = { floor: 1, turn: 0, player: { hp: 200, max_hp: 200, mana: 6, max_mana: 6 },
              enemies: [enemy("Rapide").merge(vitesse: { mastery: 30, bonus: 0 })], log: [],
              status: "active", player_statuses: [], player_debuffs: {} }
    @character.update!(combat_state: state)
    result = CombatService.new(@character).begin_combat!
    assert(result[:recent_log].any? { |l| l.include?("évitez l'embuscade") })
    assert_not(result[:recent_log].any? { |l| l.start_with?("Rapide vous") })
  end

  test "the protective talisman adds to Sang-Froid" do
    give("protective_talisman")
    @character.skills.find_by!(name: "Sang-Froid").update!(mastery: 1)
    service = fight([enemy("A")])
    service.send(:inflict_status_on_player, "Étourdi", 1, service.state[:enemies].first)
    assert(service.log.any? { |l| l.include?("Sang-Froid (1D+2)") })
  end

  test "hidden exploration items are not sold" do
    keys = (GameCatalog.shop_items + GameCatalog.apothecary_items).map { |i| i["key"] }
    assert_not_includes keys, "torch"
    assert_includes keys, "teleport_stone"
    assert_includes keys, "smelling_salts"
  end
end
