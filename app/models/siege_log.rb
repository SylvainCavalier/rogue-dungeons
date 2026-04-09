class SiegeLog < ApplicationRecord
  belongs_to :character

  validates :siege_week, :attack_direction, :result, presence: true
end
