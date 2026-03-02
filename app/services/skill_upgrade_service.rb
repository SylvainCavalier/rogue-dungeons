class SkillUpgradeService
  def initialize(character, skill)
    @character = character
    @skill = skill
  end

  def call
    cost = @skill.upgrade_cost

    if @character.xp < cost
      return { success: false, error: "XP insuffisante (#{@character.xp}/#{cost} nécessaires)" }
    end

    old_notation = @skill.notation
    @character.update!(xp: @character.xp - cost)
    @skill.upgrade!

    { success: true, message: "#{@skill.name} améliorée : #{old_notation} → #{@skill.notation}" }
  end
end
