module Api
  class ForgeController < BaseController
    before_action :require_character!

    def index
      char = current_character
      mastery, bonus = char.forge_roll
      damage_level = char.building_damage["forge"].to_i

      min_gold = (mastery + bonus) * 5
      max_gold = (mastery * 6 + bonus) * 5
      if damage_level == 1
        min_gold = (min_gold * 0.7).ceil
        max_gold = (max_gold * 0.7).ceil
      end

      render json: {
        equipment: GameCatalog.shop_equipment.map { |e| forge_item(e) },
        work: {
          notation: DiceRoller.notation(mastery, bonus),
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
