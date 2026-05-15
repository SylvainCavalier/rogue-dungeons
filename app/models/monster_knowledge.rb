class MonsterKnowledge < ApplicationRecord
  belongs_to :character

  validates :monster_key, presence: true, uniqueness: { scope: :character_id }

  def reveal!(keys)
    return if keys.blank?
    self.revealed_keys = (revealed_keys + Array(keys).map(&:to_s)).uniq
    save!
  end

  def revealed?(key)
    revealed_keys.include?(key.to_s)
  end
end
