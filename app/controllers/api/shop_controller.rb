module Api
  class ShopController < BaseController
    before_action :require_character!

    def index
      render json: {
        equipment: GameCatalog.shop_equipment.map { |e| shop_item(e, "equipment") },
        items: GameCatalog.shop_items.map { |i| shop_item(i, "item") }
      }
    end

    def buy
      key = params[:item_key]
      quantity = (params[:quantity] || 1).to_i
      item_type = params[:item_type]

      catalog = item_type == "equipment" ? GameCatalog.equipment(key) : GameCatalog.item(key)
      unless catalog
        return render json: { error: "Objet inconnu" }, status: :not_found
      end

      total_price = catalog["price"] * quantity
      if current_character.gold < total_price
        return render json: { error: "Or insuffisant (#{current_character.gold}/#{total_price} nécessaires)" }, status: :unprocessable_entity
      end

      current_character.update!(gold: current_character.gold - total_price)

      existing = current_character.inventory_items.find_by(item_key: key, equipped: false)
      if existing && item_type == "item"
        existing.update!(quantity: existing.quantity + quantity)
      else
        slot = item_type == "equipment" ? (catalog["slot"] || slot_for(catalog["category"])) : nil
        current_character.inventory_items.create!(
          item_key: key,
          item_type: item_type,
          quantity: quantity,
          equipped: false,
          slot: slot
        )
      end

      render json: {
        message: "#{catalog['name']} acheté(e) (x#{quantity}) pour #{total_price} pièces d'or",
        gold: current_character.gold
      }
    end

    def sell
      item = current_character.inventory_items.find(params[:id])
      quantity = (params[:quantity] || 1).to_i
      catalog = item.catalog_data

      if item.equipped?
        return render json: { error: "Déséquipez l'objet avant de le vendre" }, status: :unprocessable_entity
      end

      sell_price = ((catalog&.dig("price") || 0) / 2.0).ceil * quantity
      current_character.update!(gold: current_character.gold + sell_price)

      if item.quantity > quantity
        item.update!(quantity: item.quantity - quantity)
      else
        item.destroy!
      end

      render json: {
        message: "#{catalog&.dig('name') || item.item_key} vendu(e) (x#{quantity}) pour #{sell_price} pièces d'or",
        gold: current_character.gold
      }
    end

    private

    def shop_item(catalog, type)
      {
        key: catalog["key"],
        name: catalog["name"],
        category: catalog["category"],
        tier: catalog["tier"],
        price: catalog["price"],
        item_type: type,
        data: catalog
      }
    end

    def slot_for(category)
      case category
      when "arme_de_melee", "arme_a_distance" then "weapon"
      when "armure" then "armor"
      when "casque" then "helmet"
      when "bottes" then "boots"
      when "bouclier" then "shield"
      end
    end
  end
end
