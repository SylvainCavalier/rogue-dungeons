require "test_helper"

class DurabilityTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "dura-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
    @key = GameCatalog.shop_equipment.find { |e| e["price"].to_i >= 100 }["key"]
    @worn = @character.inventory_items.create!(item_key: @key, item_type: "equipment", quantity: 1,
                                               equipped: true, slot: "weapon")
    @bag = @character.inventory_items.create!(item_key: @key, item_type: "equipment", quantity: 1,
                                              equipped: false, slot: "weapon")
  end

  def finish(result)
    @character.update!(combat_state: { floor: 1, turn: 1, player: { hp: 10, max_hp: 10, mana: 0, max_mana: 0 },
                                       enemies: [], log: [], status: "active", player_statuses: [] })
    CombatService.new(@character).send(:finish_combat, result)
  end

  test "a won fight wears the equipped items by 1, not the bag" do
    out = finish(:victory)
    assert_equal 99, @worn.reload.durability
    assert_equal 100, @bag.reload.durability
    assert(out[:log].any? { |l| l.include?("Usure") })
  end

  test "a lost fight wears by 10, never below 0" do
    finish(:defeat)
    assert_equal 90, @worn.reload.durability
    @worn.update!(durability: 5)
    finish(:defeat)
    assert_equal 0, @worn.reload.durability
  end

  test "an item reaching 0 is unequipped and loses its effects" do
    @worn.update!(durability: 1)
    out = finish(:victory)
    @worn.reload
    assert_equal 0, @worn.durability
    refute @worn.equipped?
    assert_nil @character.reload.equipped_weapon
    assert(out[:log].any? { |l| l.include?("hors d'usage") })
  end

  test "repair cost: 100% durability = half the sell price" do
    price = @worn.sell_price
    assert_equal 0, @worn.repair_cost
    @worn.update!(durability: 0)
    assert_equal (price / 2.0).ceil, @worn.repair_cost
    @worn.update!(durability: 98)
    assert_equal (price / 100.0).ceil, @worn.repair_cost
  end
end
