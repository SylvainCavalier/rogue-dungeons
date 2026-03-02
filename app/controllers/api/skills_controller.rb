module Api
  class SkillsController < BaseController
    before_action :require_character!

    def index
      skills = current_character.skills.order(:category, :name)
      render json: {
        skills: skills.map { |s| skill_json(s) },
        available_xp: current_character.xp
      }
    end

    def upgrade
      skill = current_character.skills.find(params[:id])
      service = SkillUpgradeService.new(current_character, skill)
      result = service.call

      if result[:success]
        render json: {
          skill: skill_json(skill.reload),
          xp_remaining: current_character.reload.xp,
          message: result[:message]
        }
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    private

    def skill_json(skill)
      {
        id: skill.id,
        name: skill.name,
        category: skill.category,
        mastery: skill.mastery,
        bonus: skill.bonus,
        notation: skill.notation,
        upgrade_cost: skill.upgrade_cost
      }
    end
  end
end
