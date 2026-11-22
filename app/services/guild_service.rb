class GuildService
  def initialize(character)
    @character = character
  end

  def start(technique_key)
    return { success: false, error: "Votre personnage est occupé" } if @character.busy?
    return { success: false, error: "Vous êtes en combat" } if @character.in_combat?
    return { success: false, error: "Un siège est en cours !" } if @character.in_siege?
    return { success: false, error: "La guilde est détruite, réparez-la d'abord" } if @character.building_destroyed?("guild")

    technique = GameCatalog.technique(technique_key)
    return { success: false, error: "Technique inconnue" } unless technique

    if @character.learned_techniques.exists?(technique_key: technique_key)
      return { success: false, error: "Vous connaissez déjà cette technique" }
    end

    ranks = GuildRankService.new(@character, "warriors")
    required = GuildRankService.required_rank_for_technique(technique_key)
    unless ranks.allowed?(required)
      return { success: false, error: "Rang #{ranks.rank_name(required)} de la guilde requis (vous : #{ranks.rank_name})" }
    end

    if (missing = self.class.missing_requirement(@character, technique_key))
      return { success: false, error: "Il faut d'abord maîtriser #{missing['name']}" }
    end

    all_in_category = GameCatalog.techniques_for_category(technique["category"])
    rank = all_in_category.index { |t| t["key"] == technique_key }.to_i + 1

    days_needed = [(rank * 2) - @character.vigueur, 1].max
    days_needed += 2 if @character.building_damaged?("guild")

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

  # Technique data of the prerequisite still to learn, or nil.
  def self.missing_requirement(character, technique_key, learned_keys = nil)
    required = GameCatalog.technique_data(technique_key)&.dig("requires")
    return nil if required.blank?

    learned_keys ||= character.learned_techniques.pluck(:technique_key)
    learned_keys.include?(required) ? nil : (GameCatalog.technique(required) || { "name" => required })
  end

  def advance
    unless @character.activity == "guilde"
      return { success: false, error: "Vous n'êtes pas en entraînement à la guilde" }
    end

    siege_triggered = @character.advance_day

    if @character.activity_days_left&.positive?
      return {
        success: true,
        completed: false,
        message: "Jour d'entraînement passé. Encore #{@character.activity_days_left} jour(s)",
        days_left: @character.activity_days_left,
        date: @character.formatted_date,
        siege_pending: siege_triggered || false
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
