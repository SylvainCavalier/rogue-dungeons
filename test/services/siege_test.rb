require "test_helper"
require "minitest/mock"

class SiegeTest < ActiveSupport::TestCase
  MISS = { hit: false, graze: false, attack: { total: 1 }, defense: { total: 20 }, margin: -19 }.freeze
  HIT = { hit: true, graze: false, attack: { total: 20 }, defense: { total: 1 }, margin: 19 }.freeze

  setup do
    user = User.create!(email: "siege-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Gardien", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
    @character.update!(gold: 1000)
  end

  def enemy(name, hp: 30, xp: 10, gold: 10)
    stat = { mastery: 1, bonus: 0 }
    { key: "unknown", name: name, hp: hp, max_hp: hp, vigueur: stat, attack: stat,
      damage: { mastery: 2, bonus: 0 }, esquive: stat, dr: { mastery: 0, bonus: 0 }, vitesse: stat,
      xp_value: xp, gold_value: gold, abilities: [], ability_chance: 0, resistances: {}, statuses: [],
      debuffs: {}, initiative: 1 }
  end

  def fight(enemies, floor: 0, allies: [])
    @character.update!(combat_state: {
      floor: floor, turn: 1, player: { hp: 30, max_hp: 30, mana: 10, max_mana: 10 },
      enemies: enemies, allies: allies, log: [], status: "active", player_statuses: [], player_debuffs: {},
      player_initiative: 10
    })
  end

  def act(stub, type = "attack")
    DiceRoller.stub(:opposed_roll, stub) { CombatService.new(@character.reload).player_action(type, target: 0) }
  end

  # --- Waves ---

  test "siege waves grow with the weeks, up to the cap" do
    max = GameCatalog.siege_wave_scaling["max_enemies"]
    sizes = [1, 4, 10, 19, 60].map { |w| SiegeWaveFactory.build_for_week(w).size }
    assert_equal sizes, sizes.sort
    assert sizes.first >= 2
    assert_equal max, sizes.last
    assert sizes.last > 3
  end

  test "late waves get an attack and damage bonus" do
    early = SiegeWaveFactory.build_for_week(37).find { |e| e[:key] == "golem_siege" }
    late = SiegeWaveFactory.build_for_week(80).find { |e| e[:key] == "golem_siege" }
    total = ->(s) { s[:mastery] * 3 + s[:bonus] }
    assert total.(late[:attack]) > total.(early[:attack])
    assert total.(late[:damage]) > total.(early[:damage])
    assert late[:max_hp] > early[:max_hp]
  end

  # --- Rewards ---

  test "a siege victory only gives a share of the assailants' value" do
    fight([enemy("A", hp: 1, xp: 50, gold: 50)])
    result = DiceRoller.stub(:roll, { total: 30, rolls: [] }) { act(HIT) }
    assert_equal "victory", result[:status]
    rewards = GameCatalog.siege_rewards
    assert_equal (50 * rewards["xp_percent"] / 100.0).ceil, result[:rewards][:xp]
    assert_equal (50 * rewards["gold_percent"] / 100.0).ceil, result[:rewards][:gold]
    assert result[:rewards][:xp] < 50
  end

  # --- Dodge is never 100% ---

  test "a dodged blow can still land" do
    CombatService.unavoidable_hit_chance = 100
    @character.update!(defense_mode: "esquive")
    fight([enemy("A")])
    result = act(MISS, "analyze")
    assert(result[:recent_log].any? { |l| l.include?("Coup imparable") })
    assert result[:player][:hp] < 30
  end

  test "the unavoidable blow does not apply to a parry" do
    CombatService.unavoidable_hit_chance = 100
    @character.update!(defense_mode: "parade")
    fight([enemy("A")])
    result = act(MISS, "analyze")
    assert(result[:recent_log].none? { |l| l.include?("Coup imparable") })
  end

  # --- Recruitment ---

  test "recruits are limited per week and by the fortress capacity" do
    service = DefenderService.new(@character)
    assert service.recruit("milicien")[:success]
    assert service.recruit("milicien")[:success]
    refute service.recruit("milicien")[:success], "2 recruits per week"

    @character.update!(week: @character.week + 1)
    assert_equal 2, DefenderService.new(@character).recruits_left
    result = DefenderService.new(@character).recruit("milicien")
    refute result[:success], "fortress level 0 holds 2 defenders"
    assert_match "Capacité", result[:error]

    @character.update!(fortress_level: 1)
    assert DefenderService.new(@character).recruit("milicien")[:success]
    assert_equal 3, @character.town_defenders.count
  end

  test "better defenders require a rank in the warriors guild" do
    refute DefenderService.new(@character).recruit("garde")[:success]
    @character.update!(warrior_rank: 1)
    assert DefenderService.new(@character).recruit("garde")[:success]
    refute DefenderService.new(@character).recruit("chevalier")[:success]
  end

  test "defenders are posted at a gate or kept in reserve" do
    defender = @character.town_defenders.create!(defender_key: "milicien")
    assert DefenderService.new(@character).station(defender.id, "nord")[:success]
    assert_equal "nord", defender.reload.direction
    assert DefenderService.new(@character).station(defender.id, "")[:success]
    assert_nil defender.reload.direction
    refute DefenderService.new(@character).station(defender.id, "centre")[:success]
  end

  # --- Defenders in the siege ---

  test "the defenders of the attacked gate fight as allies" do
    @character.update!(siege_state: { "pending" => true, "siege_week" => 1 })
    direction = SiegeService.new(@character).send(:determine_attack_direction, 1)
    other = (FortressDefense::DIRECTIONS - [direction]).first
    posted = @character.town_defenders.create!(defender_key: "garde", direction: direction)
    @character.town_defenders.create!(defender_key: "archer", direction: other)

    result = SiegeService.new(@character.reload).prepare_siege
    allies = result[:allies] || []
    assert_equal ["Garde de la ville"], allies.map { |a| a[:name] }
    assert allies.first[:defender]
    assert_equal posted.id, @character.reload.combat_state["allies"].first["defender_id"]
  end

  test "fallen defenders are lost after the siege, the survivors stay" do
    fallen = @character.town_defenders.create!(defender_key: "milicien", direction: "nord")
    alive = @character.town_defenders.create!(defender_key: "garde", direction: "nord")
    @character.update!(siege_state: { "pending" => false, "siege_week" => 1, "attack_direction" => "nord" })

    outcome = SiegeService.new(@character).send(:finish_siege, :victory,
      { turn: 2, rewards: {}, allies: [{ defender_id: fallen.id, hp: 0 }, { defender_id: alive.id, hp: 5 }] },
      @character.siege_state)
    assert_equal ["Milicien"], outcome[:fallen_defenders]
    assert_equal [alive.id], @character.town_defenders.reload.pluck(:id)
  end

  test "a summon does not send the defenders away" do
    defender = @character.town_defenders.create!(defender_key: "garde")
    ally = DefenderService.build_ally(defender)
    @character.learned_magics.create!(magic_key: "familier", name: "Familier", element: "invocation", tier: 1)
    fight([enemy("A")], allies: [ally])
    result = DiceRoller.stub(:opposed_roll, MISS) { CombatService.new(@character.reload).player_action("magic", key: "familier") }
    names = result[:allies].map { |a| a[:name] }
    assert_includes names, "Garde de la ville"
    assert_includes names, "Familier"
  end

  test "several allies share the enemy blows with the player" do
    allies = Array.new(3) { DefenderService.build_ally(@character.town_defenders.create!(defender_key: "garde")) }
    fight([enemy("A")], allies: allies)
    service = CombatService.new(@character.reload)
    picks = Array.new(400) { service.send(:roll_enemy_target, nil) }
    player_share = picks.count(nil) / 400.0
    assert player_share.between?(0.1, 0.4), "player aimed at #{player_share}"
    assert_equal [0, 1, 2], picks.compact.uniq.sort
  end
end
