module Api
  class TownController < BaseController
    before_action :require_character!

    def status
      char = current_character
      render json: {
        date: char.formatted_date,
        activity: char.activity,
        activity_days_left: char.activity_days_left,
        activity_data: char.activity_data,
        busy: char.busy?,
        in_combat: char.in_combat?,
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana,
        gold: char.gold,
        xp: char.xp,
        current_floor: char.current_floor
      }
    end

    def work
      result = WorkService.new(current_character).call
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    def rest
      char = current_character
      return render json: { error: "Votre personnage est occupé" }, status: :unprocessable_entity if char.busy?
      return render json: { error: "Vous êtes en combat" }, status: :unprocessable_entity if char.in_combat?

      old_hp = char.current_hp
      char.full_heal
      char.advance_day
      healed = char.current_hp - old_hp

      render json: {
        message: "Vous vous reposez et récupérez #{healed} PV et toute votre mana",
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana,
        date: char.formatted_date
      }
    end

    def academy_start
      result = AcademyService.new(current_character).start(params[:magic_key])
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    def academy_advance
      result = AcademyService.new(current_character).advance
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    def guild_start
      result = GuildService.new(current_character).start(params[:technique_key])
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    def guild_advance
      result = GuildService.new(current_character).advance
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end

    def available_magics
      all = GameCatalog.all_magics
      learned_keys = current_character.learned_magics.pluck(:magic_key)
      render json: {
        magics: all.map { |m|
          m.merge("learned" => learned_keys.include?(m["key"]))
        }.group_by { |m| m["element"] }
      }
    end

    def available_techniques
      all = GameCatalog.all_techniques
      learned_keys = current_character.learned_techniques.pluck(:technique_key)
      render json: {
        techniques: all.map { |t|
          t.merge("learned" => learned_keys.include?(t["key"]))
        }.group_by { |t| t["category"] }
      }
    end
  end
end
