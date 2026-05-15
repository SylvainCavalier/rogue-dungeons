module Api
  class TownController < BaseController
    INN_COST = 10

    before_action :require_character!

    def status
      char = current_character
      char.update!(tower_session_active: false) if char.tower_session_active
      render json: {
        date: char.formatted_date,
        day: char.day,
        week: char.week,
        activity: char.activity,
        activity_days_left: char.activity_days_left,
        activity_data: char.activity_data,
        busy: char.busy?,
        in_combat: char.in_combat?,
        in_siege: char.in_siege?,
        siege_pending: char.siege_pending?,
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana,
        gold: char.gold,
        xp: char.xp,
        current_floor: char.current_floor,
        building_damage: char.building_damage,
        days_until_siege: Character::DAYS_PER_WEEK - char.day
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

    def inn
      char = current_character
      return render json: { error: "Votre personnage est occupé" }, status: :unprocessable_entity if char.busy?
      return render json: { error: "Vous êtes en combat" }, status: :unprocessable_entity if char.in_combat?
      return render json: { error: "Un siège est en cours !" }, status: :unprocessable_entity if char.in_siege?
      return render json: { error: "Or insuffisant (#{char.gold}/#{INN_COST} nécessaires)" }, status: :unprocessable_entity if char.gold < INN_COST

      char.update!(gold: char.gold - INN_COST)
      old_hp = char.current_hp
      char.full_heal
      siege_triggered = char.advance_day
      healed = char.current_hp - old_hp

      render json: {
        message: "Vous passez la nuit à l'auberge (-#{INN_COST} or) et récupérez #{healed} PV et toute votre mana",
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana,
        gold: char.gold,
        date: char.formatted_date,
        siege_pending: siege_triggered || false
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
      intelligence = current_character.intelligence
      damaged = current_character.building_damaged?("academy")

      magics = all.map do |m|
        details = GameCatalog.magic_data(m["key"]) || {}
        tier = m["tier"].to_i
        days = [(tier * 3) - intelligence, 1].max
        days += 2 if damaged
        m.merge(
          "learned" => learned_keys.include?(m["key"]),
          "description" => details["description"],
          "mana_cost" => details["mana_cost"],
          "days_needed" => days
        )
      end

      render json: { magics: magics.group_by { |m| m["element"] } }
    end

    def available_techniques
      all = GameCatalog.all_techniques
      learned_keys = current_character.learned_techniques.pluck(:technique_key)
      vigueur = current_character.vigueur
      damaged = current_character.building_damaged?("guild")

      grouped = all.group_by { |t| t["category"] }.transform_values do |techs|
        techs.each_with_index.map do |t, idx|
          details = GameCatalog.technique_data(t["key"]) || {}
          rank = idx + 1
          days = [(rank * 2) - vigueur, 1].max
          days += 2 if damaged
          t.merge(
            "learned" => learned_keys.include?(t["key"]),
            "description" => details["description"],
            "rank" => rank,
            "days_needed" => days
          )
        end
      end

      render json: { techniques: grouped }
    end
  end
end
