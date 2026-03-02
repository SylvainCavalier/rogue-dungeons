module Api
  class InventoryController < BaseController
    before_action :require_character!

    def index
      items = current_character.inventory_items.order(:item_type, :item_key)
      render json: {
        items: items.map { |i| item_json(i) },
        equipment: equipped_json
      }
    end

    def equip
      item = current_character.inventory_items.find(params[:id])

      unless item.item_type == "equipment"
        return render json: { error: "Cet objet ne peut pas être équipé" }, status: :unprocessable_entity
      end

      catalog = item.catalog_data
      slot = catalog&.dig("slot") || slot_for_category(catalog&.dig("category"))

      unless slot
        return render json: { error: "Emplacement inconnu pour cet équipement" }, status: :unprocessable_entity
      end

      current_character.inventory_items.where(slot: slot, equipped: true).update_all(equipped: false)
      item.update!(equipped: true, slot: slot)

      render json: {
        message: "#{item.display_name} équipé(e)",
        item: item_json(item.reload),
        equipment: equipped_json
      }
    end

    def unequip
      item = current_character.inventory_items.find(params[:id])

      unless item.equipped?
        return render json: { error: "Cet objet n'est pas équipé" }, status: :unprocessable_entity
      end

      item.update!(equipped: false)

      render json: {
        message: "#{item.display_name} déséquipé(e)",
        item: item_json(item.reload),
        equipment: equipped_json
      }
    end

    def use
      item = current_character.inventory_items.find(params[:id])
      catalog = item.catalog_data

      unless catalog&.dig("consumable")
        return render json: { error: "Cet objet n'est pas consommable" }, status: :unprocessable_entity
      end

      result = apply_item_effect(catalog)

      if item.quantity > 1
        item.update!(quantity: item.quantity - 1)
      else
        item.destroy!
      end

      render json: {
        message: result[:message],
        character: character_summary
      }
    end

    private

    def apply_item_effect(catalog)
      char = current_character
      case catalog["effect_type"]
      when "heal"
        heal = DiceRoller.roll(catalog["heal_mastery"] || 1, catalog["value"] || 0)[:total]
        actual_heal = [heal, char.max_hp - char.current_hp].min
        char.update!(current_hp: char.current_hp + actual_heal)
        { message: "Vous récupérez #{actual_heal} PV (#{char.current_hp}/#{char.max_hp})" }
      when "restore_mana"
        restore = DiceRoller.roll(catalog["heal_mastery"] || 1, catalog["value"] || 0)[:total]
        actual = [restore, char.max_mana - char.current_mana].min
        char.update!(current_mana: char.current_mana + actual)
        { message: "Vous récupérez #{actual} mana (#{char.current_mana}/#{char.max_mana})" }
      when "cure_status"
        char.update!(status: nil, status_duration: 0)
        { message: "Statuts négatifs retirés" }
      when "damage"
        { message: "Fiole utilisée (effet en combat uniquement)" }
      when "buff"
        { message: "Buff appliqué : #{catalog['notes']}" }
      when "xp"
        char.update!(xp: char.xp + catalog["value"].to_i)
        { message: "Vous gagnez #{catalog['value']} points d'expérience" }
      else
        { message: "Objet utilisé" }
      end
    end

    def item_json(inv_item)
      catalog = inv_item.catalog_data || {}
      {
        id: inv_item.id,
        item_key: inv_item.item_key,
        item_type: inv_item.item_type,
        name: catalog["name"] || inv_item.item_key.humanize,
        quantity: inv_item.quantity,
        equipped: inv_item.equipped,
        slot: inv_item.slot,
        data: catalog
      }
    end

    def equipped_json
      equipped = {}
      %w[weapon armor helmet boots shield].each do |slot|
        item = current_character.inventory_items.find_by(equipped: true, slot: slot)
        equipped[slot] = item ? item_json(item) : nil
      end
      equipped
    end

    def character_summary
      char = current_character
      { current_hp: char.current_hp, max_hp: char.max_hp, current_mana: char.current_mana, max_mana: char.max_mana, xp: char.xp, gold: char.gold }
    end

    def slot_for_category(category)
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
