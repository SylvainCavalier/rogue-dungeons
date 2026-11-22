module Api
  # Recruitment tab of the warriors guild: town defenders for the sieges (DefenderService).
  class RecruitsController < BaseController
    before_action :require_character!

    # GET /api/town/recruits
    def index
      render json: DefenderService.new(current_character).info
    end

    # POST /api/town/recruits  { defender_key }
    def create
      render_result(DefenderService.new(current_character).recruit(params[:defender_key].to_s))
    end

    # DELETE /api/town/recruits/:id
    def destroy
      render_result(DefenderService.new(current_character).dismiss(params[:id]))
    end

    private

    def render_result(result)
      return render json: { error: result[:error] }, status: :unprocessable_entity unless result[:success]

      service = DefenderService.new(current_character.reload)
      render json: service.info.merge(message: result[:message])
    end
  end
end
