module Api
  class ForgeController < BaseController
    before_action :require_character!

    def index
      render json: {
        equipment: GameCatalog.shop_equipment.map { |e| forge_item(e) },
        work: WorkService.info(current_character, "forge"),
        repairs: repairable_items.map { |i| repair_json(i) }
      }
    end

    # Repairs the selected damaged equipment (params[:ids]) back to full durability.
    def repair
      if current_character.building_destroyed?("forge")
        return render json: { error: "La forge est détruite, réparez-la d'abord" }, status: :unprocessable_entity
      end

      ids = Array(params[:ids]).map(&:to_i)
      items = repairable_items.select { |i| ids.include?(i.id) }
      return render json: { error: "Aucun équipement à réparer" }, status: :unprocessable_entity if items.empty?

      total = items.sum(&:repair_cost)
      if current_character.gold < total
        return render json: { error: "Or insuffisant (#{current_character.gold}/#{total} nécessaires)" },
                      status: :unprocessable_entity
      end

      InventoryItem.transaction do
        current_character.update!(gold: current_character.gold - total)
        items.each { |i| i.update!(durability: InventoryItem::MAX_DURABILITY) }
      end

      names = items.map(&:display_name).join(", ")
      render json: {
        message: "#{names} réparé#{'s' if items.size > 1} pour #{total} pièces d'or",
        gold: current_character.gold,
        repairs: repairable_items.map { |i| repair_json(i) }
      }
    end

    private

    def repairable_items
      current_character.inventory_items.where(item_type: "equipment")
                       .where("durability < ?", InventoryItem::MAX_DURABILITY)
                       .order(:durability, :item_key).to_a
    end

    def repair_json(item)
      {
        id: item.id,
        item_key: item.item_key,
        name: item.display_name,
        equipped: item.equipped,
        durability: item.durability,
        max_durability: InventoryItem::MAX_DURABILITY,
        repair_cost: item.repair_cost,
        enchantment: item.enchantment_effect,
        data: item.catalog_data
      }
    end

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
