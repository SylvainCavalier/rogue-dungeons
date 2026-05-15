class FortressDefense < ApplicationRecord
  belongs_to :character

  DIRECTIONS = %w[nord sud est ouest].freeze

  validates :trap_key, presence: true
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :durability, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_durability, numericality: { only_integer: true, greater_than: 0 }

  def broken?
    durability <= 0
  end

  def damaged?
    durability < max_durability
  end

  def trap_data
    GameCatalog.siege_trap(trap_key)
  end

  def repair_cost
    return 0 unless damaged?

    trap = trap_data
    base_cost = trap ? (trap["cost"] || 0) : 0
    ratio = GameCatalog.defense_repair_ratio
    missing = max_durability - durability
    (base_cost * ratio * missing.to_f / max_durability).ceil
  end
end
