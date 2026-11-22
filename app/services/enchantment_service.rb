class EnchantmentService
  # Enchanting an equipment piece at the academy (config/catalog/enchantements.yml).
  # Enchantement roll total → level (0 = failure). Costs gold + soul stones per item
  # tier, paid even on failure. A success replaces the item's previous enchantment.
  DAMAGED_PRICE_MULTIPLIER = 1.25

  class << self
    def info(character)
      mastery, bonus = character.enchantment_roll
      items = character.inventory_items.where(item_type: "equipment").order(:item_key, :id)
      {
        soul_stones: character.soul_stones,
        gold: character.gold,
        notation: DiceRoller.notation(mastery, bonus),
        thresholds: thresholds,
        damage_level: character.building_damage["academy"].to_i,
        items: items.filter_map { |item| item_json(character, item) }
      }
    end

    def thresholds
      GameCatalog.enchantments_data["thresholds"] || []
    end

    def cost(character, item)
      cfg = GameCatalog.enchantments_data["cost"] || {}
      tier = [item.catalog_data&.dig("tier").to_i, 1].max
      gold = tier * cfg["gold_per_tier"].to_i
      gold = (gold * DAMAGED_PRICE_MULTIPLIER).ceil if character.building_damaged?("academy")
      { gold: gold, soul_stones: tier * cfg["soul_stones_per_tier"].to_i }
    end

    # Level reached with a roll total (0 when below the first threshold).
    def level_for(total)
      thresholds.count { |t| total >= t }
    end

    private

    def item_json(character, item)
      catalog = item.catalog_data
      category = catalog&.dig("category")
      effects = GameCatalog.enchantment_effects_for(category)
      return nil if effects.empty?

      {
        id: item.id,
        item_key: item.item_key,
        name: catalog["name"],
        category: category,
        tier: catalog["tier"],
        equipped: item.equipped,
        enchantment: item.enchantment_effect,
        cost: cost(character, item),
        effects: effects.map do |effect|
          {
            key: effect["key"],
            name: effect["name"],
            description: effect["description"],
            levels: (1..thresholds.size).map do |lvl|
              InventoryItem.resolve_enchantment(category, effect["key"], lvl)&.dig(:label)
            end
          }
        end
      }
    end
  end

  def initialize(character)
    @character = character
  end

  def call(item_id, effect_key)
    item = @character.inventory_items.find_by(id: item_id, item_type: "equipment")
    cost = item && self.class.cost(@character, item)
    error = validation_error(item, effect_key, cost)
    return failure(error) if error

    mastery, bonus = @character.enchantment_roll
    roll = DiceRoller.roll(mastery, bonus)
    level = self.class.level_for(roll[:total])
    roll_text = "Enchantement (#{DiceRoller.notation(mastery, bonus)}) : #{roll[:total]}"

    ActiveRecord::Base.transaction do
      @character.update!(gold: @character.gold - cost[:gold], soul_stones: @character.soul_stones - cost[:soul_stones])
      item.update!(enchantment: { "effect" => effect_key, "level" => level }) if level.positive?
    end

    resolved = item.reload.enchantment_effect if level.positive?
    message = if level.positive?
                "#{roll_text} — #{item.display_name} reçoit l'enchantement #{resolved[:label]} (niveau #{level})"
              else
                "#{roll_text} — l'enchantement échoue, l'or et les pierres d'âme sont perdus"
              end

    {
      success: true,
      enchanted: level.positive?,
      level: level,
      roll: roll,
      message: message,
      enchantment: resolved,
      gold: @character.gold,
      soul_stones: @character.soul_stones
    }
  end

  private

  def validation_error(item, effect_key, cost)
    return "Vous êtes en combat" if @character.in_combat?
    return "L'académie est détruite, réparez-la d'abord" if @character.building_destroyed?("academy")
    return "Équipement introuvable" unless item

    category = item.catalog_data&.dig("category")
    unless GameCatalog.enchantment_effects_for(category).any? { |e| e["key"] == effect_key }
      return "Cet enchantement n'est pas possible sur cet équipement"
    end
    return "Or insuffisant (#{@character.gold}/#{cost[:gold]} nécessaires)" if @character.gold < cost[:gold]
    return nil if @character.soul_stones >= cost[:soul_stones]

    "Pierres d'âme insuffisantes (#{@character.soul_stones}/#{cost[:soul_stones]} nécessaires)"
  end

  def failure(error)
    { success: false, error: error }
  end
end
