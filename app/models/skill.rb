class Skill < ApplicationRecord
  belongs_to :character

  validates :name, presence: true, uniqueness: { scope: :character_id }
  validates :category, presence: true
  validates :mastery, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :bonus, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 3 }

  def notation
    bonus.positive? ? "#{mastery}D+#{bonus}" : "#{mastery}D"
  end

  def upgrade_cost
    mastery
  end

  def upgrade!
    self.bonus += 1
    if bonus >= 3
      self.bonus = 0
      self.mastery += 1
    end
    save!
  end
end
