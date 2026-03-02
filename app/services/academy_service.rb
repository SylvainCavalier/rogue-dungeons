class AcademyService
  def initialize(character)
    @character = character
  end

  def start(magic_key)
    return { success: false, error: "Votre personnage est occupé" } if @character.busy?
    return { success: false, error: "Vous êtes en combat" } if @character.in_combat?

    magic = GameCatalog.magic(magic_key)
    return { success: false, error: "Magie inconnue" } unless magic

    if @character.learned_magics.exists?(magic_key: magic_key)
      return { success: false, error: "Vous connaissez déjà cette magie" }
    end

    previous_tier = magic["tier"] - 1
    if previous_tier > 0
      has_previous = @character.learned_magics
        .joins("") # no join needed
        .where(element: magic["element"])
        .any? { |lm| (GameCatalog.magic(lm.magic_key)&.dig("tier") || 0) >= previous_tier }

      element_magics = GameCatalog.magics_for_element(magic["element"])
      previous_magic = element_magics.find { |m| m["tier"] == previous_tier }
      if previous_magic && !@character.learned_magics.exists?(magic_key: previous_magic["key"])
        return { success: false, error: "Vous devez d'abord apprendre #{previous_magic['name']}" }
      end
    end

    days_needed = [(magic["tier"] * 3) - @character.intelligence, 1].max

    @character.update!(
      activity: "academie",
      activity_days_left: days_needed,
      activity_data: { magic_key: magic_key, magic_name: magic["name"], element: magic["element"], tier: magic["tier"] }
    )

    {
      success: true,
      message: "Vous commencez l'apprentissage de #{magic['name']} (#{days_needed} jours)",
      days_needed: days_needed
    }
  end

  def advance
    unless @character.activity == "academie"
      return { success: false, error: "Vous n'êtes pas en apprentissage à l'académie" }
    end

    @character.advance_day

    if @character.activity_days_left&.positive?
      return {
        success: true,
        completed: false,
        message: "Jour d'étude passé. Encore #{@character.activity_days_left} jour(s)",
        days_left: @character.activity_days_left,
        date: @character.formatted_date
      }
    end

    data = @character.activity_data
    magic = GameCatalog.magic(data["magic_key"])
    @character.learned_magics.create!(
      magic_key: data["magic_key"],
      name: data["magic_name"],
      element: data["element"],
      tier: data["tier"]
    )
    @character.update!(activity: nil, activity_days_left: 0, activity_data: {})

    {
      success: true,
      completed: true,
      message: "Vous avez appris #{data['magic_name']} !",
      magic: { key: data["magic_key"], name: data["magic_name"], element: data["element"], tier: data["tier"] },
      date: @character.formatted_date
    }
  end
end
