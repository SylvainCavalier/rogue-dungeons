module Api
  class EnchantmentsController < BaseController
    before_action :require_character!

    # Academy "Enchantement" tab: enchantable equipment, costs and the player's dice.
    def index
      render json: EnchantmentService.info(current_character)
    end

    def create
      result = EnchantmentService.new(current_character).call(params[:item_id], params[:effect])
      if result[:success]
        render json: result
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end
  end
end
