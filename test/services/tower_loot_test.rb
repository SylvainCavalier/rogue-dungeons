require "test_helper"

class TowerLootTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "loot-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
    @cfg = GameCatalog.loot_data
  end

  def service_on(floor)
    @character.update!(combat_state: { floor: floor, turn: 1, player: { hp: 10, max_hp: 10, mana: 0, max_mana: 0 },
                                       enemies: [], log: [], status: "active", player_statuses: [] })
    CombatService.new(@character)
  end

  test "a roll under 5 never finds anything, even on a boss floor" do
    assert_empty service_on(10).send(:resolve_tower_loot, 4)
  end

  test "find chance rises with the Fouille roll" do
    service = service_on(1)
    chances = [5, 10, 15, 20, 25, 40].map { |r| service.send(:loot_find_chance, @cfg, r) }
    assert_equal chances.sort, chances
    assert chances.last < 100
  end

  test "the floor caps the tier: a great roll never raises it" do
    service = service_on(1)
    assert_equal 1, service.send(:loot_tier, @cfg, 1, 6, false)
    assert_equal 1, service.send(:loot_tier, @cfg, 1, 40, false)    # great roll: still T1
    assert_equal 2, service.send(:loot_tier, @cfg, 10, 40, true)    # boss: +1 only
    assert_equal 2, service.send(:loot_tier, @cfg, 30, 12, false)   # floor 30 = T2
    assert_equal 1, service.send(:loot_tier, @cfg, 30, 6, false)    # weak roll: −1
    assert_equal 4, service.send(:loot_tier, @cfg, 90, 40, false)   # floors 76-100 = T4
    assert_equal 5, service.send(:loot_tier, @cfg, 100, 40, true)   # final boss: T5
  end

  test "a great roll gives a second item of the same tier" do
    loot = service_on(10).send(:resolve_tower_loot, 40) # boss: 100% chance
    assert_equal 2, loot.size
    assert(loot.all? { |l| l[:tier] <= 2 })
  end

  test "a tier with nothing available falls back to the best lower tier" do
    item = service_on(1).send(:pick_loot, "item", 9)
    assert_equal GameCatalog.loot_pool("item").map { |i| i["tier"] }.max, item["tier"]
  end

  test "a good roll on the final boss drops T5 loot into the inventory" do
    loot = service_on(100).send(:resolve_tower_loot, 30)
    assert_equal 1, loot.size
    assert_equal 5, loot.first[:tier]
    assert @character.inventory_items.exists?(item_key: loot.first[:key], item_type: loot.first[:item_type])
  end

  test "hidden and passive items never drop" do
    keys = GameCatalog.loot_pool("item").map { |i| i["key"] }
    assert_not_includes keys, "torch"
    assert_not_includes keys, "compass_enchanted"
  end
end
