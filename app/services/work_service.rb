class WorkService
  # A day of work earns `roll × GOLD_PER_POINT` gold. Each workplace uses its own skill
  # (see Character#work_roll) and suffers -30% when its building is damaged.
  GOLD_PER_POINT = 5
  DAMAGED_MULTIPLIER = 0.7

  WORKPLACES = {
    "forge" => { skill: "Forge", damaged: "forge endommagée",
                 destroyed: "La forge est détruite, réparez-la d'abord" },
    "apothecary" => { skill: "Alchimie", damaged: "apothicaire endommagé",
                      destroyed: "L'apothicaire est détruit, réparez-le d'abord" }
  }.freeze

  # Expected gains shown before working: { notation:, min_gold:, max_gold:, damage_level:, can_work: }
  def self.info(character, place)
    mastery, bonus = character.work_roll(place)
    damage_level = character.building_damage[place].to_i
    min_gold = (mastery + bonus) * GOLD_PER_POINT
    max_gold = ((mastery * 6) + bonus) * GOLD_PER_POINT
    if damage_level == 1
      min_gold = (min_gold * DAMAGED_MULTIPLIER).ceil
      max_gold = (max_gold * DAMAGED_MULTIPLIER).ceil
    end

    {
      notation: DiceRoller.notation(mastery, bonus),
      skill: WORKPLACES.dig(place, :skill),
      min_gold: min_gold,
      max_gold: max_gold,
      damage_level: damage_level,
      can_work: damage_level < 2 && !character.busy? && !character.in_combat? && !character.in_siege?
    }
  end

  def initialize(character, place = "forge")
    @character = character
    @place = WORKPLACES.key?(place) ? place : "forge"
  end

  def call
    return { success: false, error: "Votre personnage est occupé" } if @character.busy?
    return { success: false, error: "Vous êtes en combat" } if @character.in_combat?
    return { success: false, error: "Un siège est en cours !" } if @character.in_siege?

    workplace = WORKPLACES[@place]
    damage_level = @character.building_damage[@place].to_i
    return { success: false, error: workplace[:destroyed] } if damage_level >= 2

    mastery, bonus = @character.work_roll(@place)
    roll = DiceRoller.roll(mastery, bonus)
    gold_earned = roll[:total] * GOLD_PER_POINT
    gold_earned = (gold_earned * DAMAGED_MULTIPLIER).ceil if damage_level == 1

    @character.update!(gold: @character.gold + gold_earned)
    siege_triggered = @character.advance_day

    penalty = damage_level == 1 ? " (#{workplace[:damaged]} : -30%)" : ""
    {
      success: true,
      message: "#{workplace[:skill]} (#{DiceRoller.notation(mastery, bonus)}) : #{roll[:total]} — " \
               "vous avez gagné #{gold_earned} pièces d'or#{penalty}",
      gold_earned: gold_earned,
      roll: roll,
      gold: @character.gold,
      date: @character.formatted_date,
      siege_pending: siege_triggered || false
    }
  end
end
