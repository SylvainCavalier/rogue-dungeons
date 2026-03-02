class LearnedMagic < ApplicationRecord
  belongs_to :character

  validates :magic_key, presence: true, uniqueness: { scope: :character_id }
  validates :name, presence: true
  validates :element, presence: true
  validates :tier, presence: true, numericality: { only_integer: true, greater_than: 0 }

  def catalog_data
    GameCatalog.magic(magic_key)
  end
end
