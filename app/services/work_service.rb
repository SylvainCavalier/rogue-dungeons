class WorkService
  def initialize(character)
    @character = character
  end

  def call
    return { success: false, error: "Votre personnage est occupé" } if @character.busy?
    return { success: false, error: "Vous êtes en combat" } if @character.in_combat?

    roll = DiceRoller.roll(@character.vigueur)
    gold_earned = roll[:total] * 5

    @character.update!(gold: @character.gold + gold_earned)
    @character.advance_day

    {
      success: true,
      message: "Vous avez travaillé à la forge et gagné #{gold_earned} pièces d'or",
      gold_earned: gold_earned,
      roll: roll,
      gold: @character.gold,
      date: @character.formatted_date
    }
  end
end
