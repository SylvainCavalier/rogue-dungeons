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

  private

  def only_one_equipped_per_slot
    return unless slot.present? && equipped?

    existing = character.inventory_items.where(slot: slot, equipped: true).where.not(id: id)
    errors.add(:slot, "Un équipement est déjà porté dans cet emplacement") if existing.exists?
  end
end
