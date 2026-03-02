class GuildService
  def initialize(character)
    @character = character
  end

  def start(technique_key)
    return { success: false, error: "Votre personnage est occupé" } if @character.busy?
    return { success: false, error: "Vous êtes en combat" } if @character.in_combat?

    technique = GameCatalog.technique(technique_key)
    return { success: false, error: "Technique inconnue" } unless technique

    if @character.learned_techniques.exists?(technique_key: technique_key)
      return { success: false, error: "Vous connaissez déjà cette technique" }
    end

    all_in_category = GameCatalog.techniques_for_category(technique["category"])
    rank = all_in_category.index { |t| t["key"] == technique_key }.to_i + 1

    days_needed = [(rank * 2) - @character.vigueur, 1].max

    @character.update!(
      activity: "guilde",
      activity_days_left: days_needed,
      activity_data: { technique_key: technique_key, technique_name: technique["name"], category: technique["category"] }
    )

    {
      success: true,
      message: "Vous commencez l'apprentissage de #{technique['name']} (#{days_needed} jours)",
      days_needed: days_needed
    }
  end

  def advance
    unless @character.activity == "guilde"
      return { success: false, error: "Vous n'êtes pas en entraînement à la guilde" }
    end

    @character.advance_day

    if @character.activity_days_left&.positive?
      return {
        success: true,
        completed: false,
        message: "Jour d'entraînement passé. Encore #{@character.activity_days_left} jour(s)",
        days_left: @character.activity_days_left,
        date: @character.formatted_date
      }
    end

    data = @character.activity_data
    @character.learned_techniques.create!(
      technique_key: data["technique_key"],
      name: data["technique_name"],
      category: data["category"]
    )
    @character.update!(activity: nil, activity_days_left: 0, activity_data: {})

    {
      success: true,
      completed: true,
      message: "Vous avez appris #{data['technique_name']} !",
      technique: { key: data["technique_key"], name: data["technique_name"], category: data["category"] },
      date: @character.formatted_date
    }
  end
end
