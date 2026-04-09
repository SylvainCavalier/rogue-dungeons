class WorkService
  def initialize(character)
    @character = character
  end

  def call
    return { success: false, error: "Votre personnage est occupé" } if @character.busy?
    return { success: false, error: "Vous êtes en combat" } if @character.in_combat?
    return { success: false, error: "Un siège est en cours !" } if @character.in_siege?

    # Malus si la forge est endommagée
    damage_level = @character.building_damage["forge"].to_i
    return { success: false, error: "La forge est détruite, réparez-la d'abord" } if damage_level >= 2

    roll = DiceRoller.roll(@character.vigueur)
    gold_earned = roll[:total] * 5
    gold_earned = (gold_earned * 0.7).ceil if damage_level == 1

    @character.update!(gold: @character.gold + gold_earned)
    siege_triggered = @character.advance_day

    {
      success: true,
      message: "Vous avez travaillé à la forge et gagné #{gold_earned} pièces d'or#{damage_level == 1 ? " (forge endommagée : -30%)" : ""}",
      gold_earned: gold_earned,
      roll: roll,
      gold: @character.gold,
      date: @character.formatted_date,
      siege_pending: siege_triggered || false
    }
  end
end
