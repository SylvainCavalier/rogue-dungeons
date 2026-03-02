class LearnedTechnique < ApplicationRecord
  belongs_to :character

  validates :technique_key, presence: true, uniqueness: { scope: :character_id }
  validates :name, presence: true
  validates :category, presence: true

  def catalog_data
    GameCatalog.technique(technique_key)
  end
end
