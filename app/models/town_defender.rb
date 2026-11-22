# A defender recruited at the warriors guild (types in config/catalog/siege.yml
# `defenders`). Posted at a gate (`direction`) or in reserve (nil); only the
# defenders of the attacked gate fight in a siege, and the fallen are lost.
class TownDefender < ApplicationRecord
  belongs_to :character

  validates :defender_key, presence: true
  validates :direction, inclusion: { in: FortressDefense::DIRECTIONS }, allow_nil: true

  def data
    GameCatalog.defender(defender_key)
  end

  def name
    data&.dig("name") || defender_key
  end
end
