module Api
  class ApothecaryController < BaseController
    before_action :require_character!

    # Potions, remedies and elixirs (items with `vendor: "apothecary"`) + alchemy work info.
    # Buying and selling go through ShopController.
    def index
      render json: {
        items: GameCatalog.apothecary_items.map { |i| apothecary_item(i) },
        work: WorkService.info(current_character, "apothecary"),
        haggle: current_character.haggle_info
      }
    end

    private

    def apothecary_item(catalog)
      {
        key: catalog["key"],
        name: catalog["name"],
        category: catalog["category"],
        price: current_character.buy_price(catalog["price"], "apothecary"),
        item_type: "item",
        data: catalog
      }
    end
  end
end
