module Api
  class ForgeController < BaseController
    before_action :require_character!

    def index
      render json: {
        equipment: GameCatalog.shop_equipment.map { |e| forge_item(e) },
        work: WorkService.info(current_character, "forge")
      }
    end

    private

    def forge_item(catalog)
      {
        key: catalog["key"],
        name: catalog["name"],
        category: catalog["category"],
        tier: catalog["tier"],
        price: catalog["price"],
        item_type: "equipment",
        data: catalog
      }
    end
  end
end
