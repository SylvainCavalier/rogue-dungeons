require "test_helper"

class ForgeRepairTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "repair-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @user.update!(auth_token: SecureRandom.hex(16)) if @user.auth_token.blank?
    @character = @user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                         charisme: 2, perception: 2)
    key = GameCatalog.shop_equipment.find { |e| e["price"].to_i >= 100 }["key"]
    @item = @character.inventory_items.create!(item_key: key, item_type: "equipment", quantity: 1,
                                               equipped: true, slot: "weapon", durability: 40)
    @headers = { "Authorization" => "Bearer #{@user.auth_token}" }
  end

  test "lists damaged items and repairs the selected ones for their cost" do
    get "/api/forge", headers: @headers
    repairs = response.parsed_body["repairs"]
    assert_equal [@item.id], repairs.map { |r| r["id"] }
    cost = repairs.first["repair_cost"]

    @character.update!(gold: cost + 5)
    post "/api/forge/repair", params: { ids: [@item.id] }, headers: @headers, as: :json
    assert_response :success
    assert_equal 100, @item.reload.durability
    assert_equal 5, @character.reload.gold
    assert_empty response.parsed_body["repairs"]
  end

  test "a broken item can't be equipped until repaired" do
    @item.update!(durability: 0, equipped: false)
    post "/api/inventory/#{@item.id}/equip", headers: @headers, as: :json
    assert_response :unprocessable_entity
    refute @item.reload.equipped?
  end

  test "refuses without enough gold" do
    @character.update!(gold: 0)
    post "/api/forge/repair", params: { ids: [@item.id] }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_equal 40, @item.reload.durability
  end
end
