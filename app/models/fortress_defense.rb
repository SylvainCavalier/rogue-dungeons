class FortressDefense < ApplicationRecord
  belongs_to :character

  DIRECTIONS = %w[nord sud est ouest].freeze

  validates :trap_key, presence: true
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
