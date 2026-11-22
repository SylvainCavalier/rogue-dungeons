module Api
  class TavernController < BaseController
    before_action :require_character!

    # Tavern games at the inn (arm wrestling, drinking contest).
    def index
      render json: TavernService.info(current_character)
    end

    def play
      result = TavernService.new(current_character).play(params[:game])
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end
  end
end
