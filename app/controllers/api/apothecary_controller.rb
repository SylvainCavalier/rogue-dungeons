module Api
  class ApothecaryController < BaseController
    before_action :require_character!

    # Potions, remedies and elixirs (items with `vendor: "apothecary"`) + alchemy work info.
    # Buying and selling go through ShopController.
    def index
      damaged = current_character.building_damaged?("apothecary")
      render json: {
        items: GameCatalog.apothecary_items.map { |i| apothecary_item(i, damaged) },
        work: WorkService.info(current_character, "apothecary")
      }
    end

    private

    def apothecary_item(catalog, damaged)
      price = catalog["price"].to_i
      {
        key: catalog["key"],
        name: catalog["name"],
        category: catalog["category"],
        price: damaged ? (price * 1.25).ceil : price,
        item_type: "item",
        data: catalog
      }
    end
  end
end
