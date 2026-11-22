require "test_helper"

class CombatServicePerceptionTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "perc-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
  end

  def enemy(name, attack: 1, abilities: [], ability_chance: nil, initiative: 1)
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: 50, max_hp: 50, vigueur: stat, attack: { mastery: attack, bonus: 0 },
      damage: stat, esquive: stat, dr: { mastery: 0, bonus: 0 }, vitesse: stat, xp_value: 1, gold_value: 1,
      abilities: abilities, ability_chance: ability_chance, resistances: {}, statuses: [], debuffs: {},
      initiative: initiative }
  end

  def service_with(enemies)
    @character.update!(combat_state: {
      floor: 1, turn: 1, player: { hp: 200, max_hp: 200, mana: 6, max_mana: 6 },
      enemies: enemies, log: [], status: "active", player_statuses: [], player_debuffs: {},
      player_initiative: 10
    })
    CombatService.new(@character)
  end

  def set_skill(name, mastery, bonus = 0)
    @character.skills.find_by!(name: name).update!(mastery: mastery, bonus: bonus)
  end

  test "Intuition reveals the planned action, and the enemy then does it" do
    set_skill("Intuition", 20)
    service = service_with([enemy("Sorcier", abilities: ["cecite"], ability_chance: 100)])
    result = service.player_action("item", item_id: 0)
    assert_equal "Cécité", result[:enemies].first[:intent]

    set_skill("Sang-Froid", 1)
    next_result = CombatService.new(@character.reload).player_action("item", item_id: 0)
    assert(next_result[:recent_log].any? { |l| l.include?("Sorcier lance Cécité") }, next_result[:recent_log].inspect)
  end

  test "a low Intuition roll against a strong enemy reveals nothing" do
    set_skill("Intuition", 1)
    result = service_with([enemy("Champion", attack: 10)]).player_action("item", item_id: 0)
    assert_nil result[:enemies].first[:intent]
    assert(result[:recent_log].any? { |l| l.include?("vous ne devinez pas") })
  end

  test "a high Sang-Froid resists mental statuses" do
    set_skill("Sang-Froid", 30)
    service = service_with([enemy("Sorcier", attack: 1)])
    service.send(:inflict_status_on_player, "Étourdi", 1, service.state[:enemies].first)
    assert_empty service.state[:player_statuses]
    assert(service.log.any? { |l| l.include?("vous résistez à Étourdi") })
  end

  test "Sang-Froid does not protect from physical statuses" do
    set_skill("Sang-Froid", 30)
    service = service_with([enemy("Sorcier")])
    service.send(:inflict_status_on_player, "Brûlé", 2, service.state[:enemies].first)
    assert_equal ["Brûlé"], service.state[:player_statuses].map { |s| s[:name] }
  end

  test "Fouille sets the soul stone drop chance from 5% to 50%" do
    set_skill("Fouille", 1)
    assert_equal 5, CombatService.soul_stone_drop_chance(@character.reload)
    set_skill("Fouille", 2, 1)
    assert_equal 13, CombatService.soul_stone_drop_chance(@character.reload)
    set_skill("Fouille", 12)
    assert_equal 50, CombatService.soul_stone_drop_chance(@character.reload)
  end
end
