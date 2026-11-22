# Ranks in the warriors guild and the mages academy (config/catalog/guildes.yml).
# A character joins (rank 1, paid) then passes free promotions once the
# conditions of the next rank are met. Techniques/magics require a rank.
class GuildRankService
  GUILDS = %w[warriors mages].freeze

  def self.config(guild)
    GameCatalog.guilds_data.dig("guilds", guild.to_s) || raise(ArgumentError, "unknown guild #{guild}")
  end

  # Rank index (1-based) needed to learn a warrior technique.
  def self.required_rank_for_technique(technique_key)
    rank_key = GameCatalog.technique_data(technique_key.to_s)&.dig("guild_rank") || "apprenti"
    rank_index("warriors", rank_key)
  end

  # Rank index needed to learn an academy magic (from its tier).
  def self.required_rank_for_magic(magic_key)
    tier = GameCatalog.magic(magic_key.to_s)&.dig("tier").to_i
    rank_key = config("mages")["tier_ranks"]&.dig(tier) || "apprenti"
    rank_index("mages", rank_key)
  end

  def self.rank_index(guild, rank_key)
    (config(guild)["ranks"].index { |r| r["key"] == rank_key } || 0) + 1
  end

  def self.rank_name(guild, index)
    return "Non-membre" if index.to_i <= 0

    config(guild)["ranks"][index - 1]&.dig("name")
  end

  def initialize(character, guild)
    @character = character
    @guild = guild.to_s
    @config = self.class.config(@guild)
  end

  def rank
    @character.public_send(@config["column"]).to_i
  end

  def rank_name(index = rank)
    self.class.rank_name(@guild, index)
  end

  def next_rank
    @config["ranks"][rank]
  end

  def allowed?(required_rank)
    rank >= required_rank
  end

  # Conditions of the next rank, each { label:, met: }.
  def conditions(rank_data = next_rank)
    return [] unless rank_data

    list = []
    if rank_data["floor"]
      list << { label: "Avoir battu l'étage #{rank_data['floor']} de la tour (vous : étage #{@character.current_floor})",
                met: @character.current_floor >= rank_data["floor"] }
    end
    if rank_data["max_mana"]
      list << { label: "#{rank_data['max_mana']} PM maximum (vous : #{@character.max_mana})",
                met: @character.max_mana >= rank_data["max_mana"] }
    end
    if rank_data["skill_mastery"]
      best = @character.skills.where(name: @config["skills"]).order(mastery: :desc).first
      list << { label: "#{@config['skills_label'].capitalize} à #{rank_data['skill_mastery']}D " \
                       "(vous : #{best ? "#{best.name} #{best.mastery}D" : 'aucune'})",
                met: best.present? && best.mastery >= rank_data["skill_mastery"] }
    end
    if rank_data["cost"].to_i.positive?
      list << { label: "Droit d'inscription : #{rank_data['cost']} or (vous : #{@character.gold} or)",
                met: @character.gold >= rank_data["cost"] }
    end
    list
  end

  # Joining (rank 0 -> 1) or promotion: every condition of the next rank must be met.
  def advance!
    return { success: false, error: "#{@config['name']} : le bâtiment est détruit, réparez-le d'abord" } if @character.building_destroyed?(@config["building"])

    rank_data = next_rank
    return { success: false, error: "Vous avez déjà le rang le plus élevé" } unless rank_data

    missing = conditions(rank_data).reject { |c| c[:met] }
    if missing.any?
      return { success: false, error: "Conditions non remplies : #{missing.map { |c| c[:label] }.join(', ')}" }
    end

    cost = rank_data["cost"].to_i
    @character.update!(@config["column"] => rank + 1, gold: @character.gold - cost)
    verb = rank == 1 ? "Vous rejoignez" : "Vous êtes promu"
    message = rank == 1 ? "#{verb} #{@config['name']} en tant que #{rank_name} !" : "#{verb} #{rank_name} de #{@config['name']} !"
    { success: true, message: message, rank: info }
  end

  # Payload for the guild/academy pages.
  def info
    nxt = next_rank
    {
      guild: @guild,
      rank: rank,
      rank_name: rank_name,
      next_rank: nxt && {
        name: nxt["name"],
        join: rank.zero?,
        cost: nxt["cost"].to_i,
        conditions: conditions(nxt),
        ready: conditions(nxt).all? { |c| c[:met] }
      }
    }
  end
end
