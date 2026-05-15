module Api
  class ForgeController < BaseController
    before_action :require_character!

    def index
      char = current_character
      vigueur = char.vigueur.to_i
      damage_level = char.building_damage["forge"].to_i

      min_gold = vigueur * 5
      max_gold = vigueur * 30
      if damage_level == 1
        min_gold = (min_gold * 0.7).ceil
        max_gold = (max_gold * 0.7).ceil
      end

      render json: {
        equipment: GameCatalog.shop_equipment.map { |e| forge_item(e) },
        work: {
          vigueur: vigueur,
          min_gold: min_gold,
          max_gold: max_gold,
          damage_level: damage_level,
          can_work: damage_level < 2 && !char.busy? && !char.in_combat? && !char.in_siege?
        }
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
