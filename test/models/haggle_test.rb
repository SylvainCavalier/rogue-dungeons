require "test_helper"

class HaggleTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "haggle-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Marchand", vigueur: 3, dexterite: 3, intelligence: 3,
                                        charisme: 1, perception: 2)
    @skill = @character.skills.find_by(name: "Marchandage")
  end

  test "Marchandage at 1D gives no discount" do
    assert_equal 0, @character.haggle_percent
    assert_equal 100, @character.buy_price(100, "shop")
  end

  test "each upgrade lowers buy prices and raises resale prices" do
    @skill.update!(mastery: 2, bonus: 1) # 4 steps -> 8%
    assert_equal 8, @character.haggle_percent
    assert_equal 92, @character.buy_price(100, "shop")

    item = @character.inventory_items.create!(item_key: GameCatalog.shop_items.first["key"], item_type: "item", quantity: 1)
    base = item.sell_price
    assert_equal (base * 1.08).floor, @character.sell_price_for(item)
  end

  test "the discount is capped and buying stays dearer than reselling" do
    @skill.update!(mastery: 20, bonus: 0)
    assert_equal Character::HAGGLE_MAX_PERCENT, @character.haggle_percent

    item = @character.inventory_items.create!(item_key: GameCatalog.shop_items.first["key"], item_type: "item", quantity: 1)
    price = item.catalog_data["price"]
    assert_operator @character.sell_price_for(item), :<, @character.buy_price(price, "shop")
  end

  test "damaged building surcharge applies before the discount" do
    @skill.update!(mastery: 2, bonus: 0) # 3 steps -> 6%
    @character.update!(building_damage: { "shop" => 1 })
    assert_equal (100 * 1.25 * 0.94).ceil, @character.buy_price(100, "shop")
  end
end
