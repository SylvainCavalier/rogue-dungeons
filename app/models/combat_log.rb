class CombatLog < ApplicationRecord
  belongs_to :character

  validates :floor, presence: true
  validates :result, presence: true, inclusion: { in: %w[victory defeat fled] }
end
