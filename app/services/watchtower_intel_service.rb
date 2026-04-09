class WatchtowerIntelService
  DIRECTIONS = FortressDefense::DIRECTIONS

  def initialize(character)
    @character = character
  end

  def predict
    attack_direction = determine_attack_direction
    level = @character.watchtower_level
    level_data = GameCatalog.watchtower_level_data(level)
    info_type = level_data&.dig("info") || "none"

    case info_type
    when "none"
      { directions: DIRECTIONS.dup, certainty: "none", message: "Aucune information disponible" }
    when "vague"
      hint = vague_hint(attack_direction)
      { directions: hint, certainty: "vague", message: "Les éclaireurs pensent que l'attaque viendra de #{hint.join(' ou ')}" }
    when "partial"
      hint = partial_hint(attack_direction)
      { directions: hint, certainty: "partial", message: "Les espions rapportent une activité ennemie à l'#{hint.join(' ou ')}" }
    when "precise"
      { directions: [attack_direction], certainty: "precise", message: "Nos espions confirment : l'attaque viendra du #{attack_direction}" }
    else
      { directions: DIRECTIONS.dup, certainty: "none", message: "Aucune information disponible" }
    end
  end

  private

  def determine_attack_direction
    seed = @character.total_weeks_elapsed * 7 + @character.id
    DIRECTIONS[seed % DIRECTIONS.length]
  end

  def vague_hint(real_direction)
    others = DIRECTIONS - [real_direction]
    [real_direction, others.sample].shuffle
  end

  def partial_hint(real_direction)
    others = DIRECTIONS - [real_direction]
    [real_direction, others.sample].shuffle
  end
end
