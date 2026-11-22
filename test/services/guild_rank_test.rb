require "test_helper"

class GuildRankTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "rank-#{SecureRandom.hex(4)}@example.test", password: "password123")
    @character = user.create_character!(name: "Recrue", vigueur: 3, dexterite: 3, intelligence: 2,
                                        charisme: 2, perception: 2)
    @character.update!(gold: 500)
  end

  def warriors = GuildRankService.new(@character.reload, "warriors")
  def mages = GuildRankService.new(@character.reload, "mages")

  test "joining the warriors guild needs floor 10 and costs 50 gold" do
    result = warriors.advance!
    assert_not result[:success]
    assert_match "étage 10", result[:error]

    @character.update!(current_floor: 10)
    result = warriors.advance!
    assert result[:success], result[:error]
    assert_equal 1, @character.reload.warrior_rank
    assert_equal 450, @character.gold
  end

  test "joining the academy needs 20 max mana instead of a floor" do
    assert_not mages.advance![:success]
    @character.update!(bonus_max_mana: 20)
    assert mages.advance![:success]
    assert_equal 1, @character.reload.mage_rank
  end

  test "promotions are free and need floor + a weapon skill (warriors)" do
    @character.update!(warrior_rank: 1, current_floor: 30)
    assert_match "compétence d'arme", warriors.advance![:error]

    @character.skills.find_by(name: "Arc").update!(mastery: 5)
    result = warriors.advance!
    assert result[:success], result[:error]
    assert_equal [2, 500], [@character.reload.warrior_rank, @character.gold]

    @character.update!(current_floor: 50)
    @character.skills.find_by(name: "Arme à deux mains").update!(mastery: 7)
    assert warriors.advance![:success]
    assert_equal "Maître", warriors.rank_name
    assert_match "plus élevé", warriors.advance![:error]
  end

  test "academy promotions need max mana and a magic skill" do
    @character.update!(mage_rank: 1, bonus_max_mana: 24) # 6 + 24 = 30
    assert_not mages.advance![:success]
    @character.skills.find_by(name: "Invocation").update!(mastery: 5)
    assert mages.advance![:success]
    assert_equal "Compagnon", mages.rank_name
  end

  test "a destroyed building refuses joining" do
    @character.update!(current_floor: 10, building_damage: { "guild" => 2 })
    assert_match "détruit", warriors.advance![:error]
  end

  test "techniques and magics require a rank to be learned" do
    assert_match "Apprenti", GuildService.new(@character).start("coup_rapide")[:error]
    @character.update!(warrior_rank: 1)
    assert GuildService.new(@character.reload).start("coup_rapide")[:success]

    @character.update!(activity: nil, activity_days_left: 0)
    assert_match "Compagnon", GuildService.new(@character.reload).start("riposte")[:error]

    @character.update!(mage_rank: 1)
    assert GuildRankService.new(@character, "mages").allowed?(GuildRankService.required_rank_for_magic("lame_aqueuse"))
    assert_equal 2, GuildRankService.required_rank_for_magic("pluie_regenerante")
    assert_equal 3, GuildRankService.required_rank_for_magic("necromancie")
    assert_match "Maître", AcademyService.new(@character.reload).start("phenix")[:error]
  end

  test "every technique has a valid guild rank" do
    GameCatalog.all_techniques.each do |t|
      rank = GameCatalog.technique_data(t["key"])["guild_rank"] || "apprenti"
      assert_includes %w[apprenti compagnon maitre], rank, t["key"]
    end
    assert_equal 3, GuildRankService.required_rank_for_technique("survie")
  end
end
