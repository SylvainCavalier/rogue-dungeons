module Api
  class TowerController < BaseController
    before_action :require_character!

    def info
      char = current_character
      next_floor = char.current_floor + 1
      floor_data = GameCatalog.floor(next_floor)

      render json: {
        current_floor: char.current_floor,
        next_floor: next_floor,
        in_combat: char.in_combat?,
        floor_preview: floor_data ? {
          enemies: floor_data["enemies"],
          boss: floor_data["boss"]
        } : nil,
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana
      }
    end

    def enter
      char = current_character

      if char.in_combat?
        return render json: { error: "Vous êtes déjà en combat" }, status: :unprocessable_entity
      end

      if char.busy?
        return render json: { error: "Votre personnage est occupé" }, status: :unprocessable_entity
      end

      unless char.alive?
        return render json: { error: "Vous êtes trop faible pour combattre" }, status: :unprocessable_entity
      end

      next_floor = char.current_floor + 1
      if next_floor > 100
        return render json: { error: "Vous avez déjà conquis la tour !" }, status: :unprocessable_entity
      end

      service = CombatService.new(char)
      result = service.start_combat(next_floor)

      render json: result
    end

    def combat
      char = current_character

      unless char.in_combat?
        return render json: { error: "Aucun combat en cours" }, status: :not_found
      end

      service = CombatService.new(char)
      render json: service.combat_snapshot
    end

    def action
      char = current_character

      unless char.in_combat?
        return render json: { error: "Aucun combat en cours" }, status: :not_found
      end

      service = CombatService.new(char)
      result = service.player_action(
        params[:action_type],
        key: params[:key],
        target: params[:target],
        item_id: params[:item_id]
      )

      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        render json: result
      end
    end

    def flee
      char = current_character

      unless char.in_combat?
        return render json: { error: "Aucun combat en cours" }, status: :not_found
      end

      service = CombatService.new(char)
      result = service.flee

      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        render json: result
      end
    end
  end
end
