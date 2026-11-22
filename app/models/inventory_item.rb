class InventoryItem < ApplicationRecord
  belongs_to :character

  EQUIPMENT_SLOTS = %w[weapon armor helmet boots shield].freeze

  validates :item_key, presence: true
  validates :item_type, presence: true, inclusion: { in: %w[equipment item] }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :slot, inclusion: { in: EQUIPMENT_SLOTS, allow_nil: true }
  validate :only_one_equipped_per_slot, if: :equipped?

  def catalog_data
    case item_type
    when "equipment"
      GameCatalog.equipment(item_key)
    when "item"
      GameCatalog.item(item_key)
    end
  end

  def display_name
    catalog_data&.dig("name") || item_key.humanize
  end

  def equipped?
    equipped
  end

  # Resolved enchantment ({ key, name, level, ladder, mastery, bonus, percent, label })
  # from the stored { "effect", "level" } and the current catalog values.
  def enchantment_effect
    return nil unless item_type == "equipment" && enchantment.is_a?(Hash)

    self.class.resolve_enchantment(catalog_data&.dig("category"), enchantment["effect"], enchantment["level"].to_i)
  end

  def self.resolve_enchantment(category, effect_key, level)
    effect = GameCatalog.enchantment_effects_for(category).find { |e| e["key"] == effect_key }
    return nil unless effect && level.positive?

    ladder = GameCatalog.enchantments_data.dig("ladders", effect["ladder"]) || []
    value = ladder[[level, ladder.size].min - 1]
    return nil unless value

    resolved = { key: effect["key"], name: effect["name"], level: level, ladder: effect["ladder"],
                 mastery: 0, bonus: 0, percent: 0 }
    if effect["ladder"] == "percent"
      resolved[:percent] = value.to_i
      resolved[:label] = "#{effect['name']} #{value}%"
    else
      resolved[:mastery] = value["mastery"].to_i
      resolved[:bonus] = value["bonus"].to_i
      resolved[:label] = "#{effect['name']} #{dice_label(resolved[:mastery], resolved[:bonus])}"
    end
    resolved
  end

  # "+2", "+1D", "+1D+2"
  def self.dice_label(mastery, bonus)
    return "+#{bonus}" if mastery.zero?

    bonus.positive? ? "+#{mastery}D+#{bonus}" : "+#{mastery}D"
  end

  private

  def only_one_equipped_per_slot
    return unless slot.present? && equipped?

    existing = character.inventory_items.where(slot: slot, equipped: true).where.not(id: id)
    errors.add(:slot, "Un équipement est déjà porté dans cet emplacement") if existing.exists?
  end
end
