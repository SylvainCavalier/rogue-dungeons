class DiceRoller
  class << self
    def roll(mastery, bonus = 0)
      rolls = Array.new([mastery, 0].max) { rand(1..6) }
      total = rolls.sum + bonus
      { total: [total, 0].max, rolls: rolls, bonus: bonus, mastery: mastery }
    end

    def opposed_roll(atk_mastery, atk_bonus, def_mastery, def_bonus)
      attack = roll(atk_mastery, atk_bonus)
      defense = roll(def_mastery, def_bonus)
      margin = attack[:total] - defense[:total]
      {
        hit: margin > 0,
        attack: attack,
        defense: defense,
        margin: margin
      }
    end

    def notation(mastery, bonus = 0)
      bonus.positive? ? "#{mastery}D+#{bonus}" : "#{mastery}D"
    end
  end
end
