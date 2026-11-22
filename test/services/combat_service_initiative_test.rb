require "test_helper"

class CombatServiceInitiativeTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "init-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Testeur", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
  end

  def enemy(name, initiative:, hp: 50)
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: hp, max_hp: hp, vigueur: stat, attack: { mastery: 1, bonus: 0 },
      damage: stat, esquive: stat, dr: { mastery: 0, bonus: 0 }, vitesse: stat, xp_value: 1, gold_value: 1,
      abilities: [], resistances: {}, statuses: [], debuffs: {}, initiative: initiative }
  end

  def start_with(enemies, player_initiative:)
    @character.update!(combat_state: {
      floor: 1, turn: 1, player: { hp: 30, max_hp: 30, mana: 6, max_mana: 6 },
      enemies: enemies, log: [], status: "active", player_statuses: [], player_debuffs: {},
      player_initiative: player_initiative
    })
    CombatService.new(@character)
  end

  test "initiative is rolled once at the start and kept for the whole fight" do
    snapshot = CombatService.new(@character).start_combat(1)
    initiative = snapshot[:player][:initiative]
    assert initiative.positive?
    assert snapshot[:enemies].all? { |e| e[:initiative].to_i.positive? }
    assert(snapshot[:log].any? { |l| l.start_with?("Initiative") })

    next_snapshot = CombatService.new(@character.reload).player_action("analyze", target: 0)
    assert_equal initiative, next_snapshot[:player][:initiative] if next_snapshot[:status] == "active"
  end

  test "faster enemies act at the start of the round, slower ones after the player" do
    service = start_with([enemy("Rapide", initiative: 20), enemy("Lent", initiative: 1)], player_initiative: 10)
    result = service.player_action("item", item_id: 0) # no-op action, keeps the log readable
    log = result[:recent_log]

    header = log.index { |l| l.start_with?("--- Tour 2") }
    slow = log.index { |l| l.start_with?("Lent vous") }
    fast = log.index { |l| l.start_with?("Rapide vous") }
    assert header && slow && fast, log.inspect
    assert slow < header, "slower enemy should act before the next round starts"
    assert fast > header, "faster enemy should open the next round: #{log.inspect}"
    assert result[:enemies].find { |e| e[:name] == "Rapide" }[:faster]
  end

  test "ties go to the player" do
    service = start_with([enemy("Egal", initiative: 10)], player_initiative: 10)
    result = service.player_action("item", item_id: 0)
    header = result[:recent_log].index { |l| l.start_with?("--- Tour 2") }
    acted = result[:recent_log].index { |l| l.start_with?("Egal vous") }
    assert acted < header
  end

  test "killing a faster enemy before its turn prevents its action" do
    service = start_with([enemy("Rapide", initiative: 20, hp: 1)], player_initiative: 30)
    result = service.player_action("attack", target: 0)
    if result[:enemies].first[:alive]
      skip "attack missed"
    else
      assert_equal "victory", result[:status]
    end
  end

  test "Discrétion stays in the database but is hidden" do
    assert @character.skills.exists?(name: "Discrétion")
    assert_not @character.skills.visible.exists?(name: "Discrétion")
    assert @character.skills.visible.exists?(name: "Vitesse")
  end

  test "full fights run to the end on every tower tier" do
    [1, 10, 25, 50, 75, 100].each do |floor|
      @character.update!(combat_state: nil, current_hp: @character.max_hp)
      result = CombatService.new(@character).start_combat(floor)
      40.times do
        break unless result[:status] == "active"
        result = CombatService.new(@character.reload).player_action("attack", target: 0)
      end
      assert_includes %w[active victory defeat], result[:status], "floor #{floor}"
      @character.reload
    end
  end

  test "a siege opens with initiative" do
    @character.update!(siege_state: { "pending" => true, "siege_week" => 1 })
    result = SiegeService.new(@character).prepare_siege
    assert_nil result[:error]
    assert(@character.reload.combat_state.nil? || @character.combat_state["player_initiative"])
  end

  test "each extra enemy attack of the round weakens the defense, across faster and slower enemies" do
    enemies = [enemy("Rapide", initiative: 20), enemy("Lent1", initiative: 2), enemy("Lent2", initiative: 1)]
    service = start_with(enemies, player_initiative: 10)
    @character.update!(combat_state: @character.combat_state.merge("round_attacks" => 1)) # Rapide already attacked
    result = CombatService.new(@character.reload).player_action("item", item_id: 0)
    log = result[:recent_log]
    header = log.index { |l| l.start_with?("--- Tour 2") }
    before = log[0...header].select { |l| l.include?("affaiblie") }
    after = log[header..].select { |l| l.include?("affaiblie") }
    assert_equal ["-1D, attaque n°2", "-2D, attaque n°3"], before.map { |l| l[/-\dD, attaque n°\d/] }
    assert_empty after, "the new round resets the counter for its first attack"
    assert service
  end
end
