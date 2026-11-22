class TavernService
  # Tavern games at the inn (config/catalog/taverne.yml): arm wrestling (Bras de fer)
  # and drinking contest (Résistance à l'alcool). Once per day each, no time passes.
  # Progress is stored in characters.tavern_games: { game => { "wins", "last_day" } }.

  class << self
    def catalog
      @catalog = nil if Rails.env.development?
      @catalog ||= YAML.load_file(Rails.root.join("config", "catalog", "taverne.yml"))
    end

    def games
      catalog["games"] || {}
    end

    def info(character)
      { games: games.keys.map { |key| game_info(character, key) } }
    end

    def game_info(character, key)
      game = games[key]
      wins = wins(character, key)
      mastery, bonus = skill_roll(character, game["skill"])
      opp_mastery, opp_bonus = opponent_dice(wins)
      {
        key: key,
        name: game["name"],
        skill: game["skill"],
        description: game["description"],
        notation: DiceRoller.notation(mastery, bonus),
        opponent: opponent_name(game, wins),
        opponent_notation: DiceRoller.notation(opp_mastery, opp_bonus),
        wins: wins,
        reward: reward(wins),
        stake: stake(wins),
        played_today: played_today?(character, key)
      }
    end

    def wins(character, key)
      character.tavern_games.dig(key, "wins").to_i
    end

    def played_today?(character, key)
      character.tavern_games.dig(key, "last_day") == character.absolute_day
    end

    # Opponent dice: base + bonus_per_win per win, every 3 bonus becomes +1D.
    def opponent_dice(wins)
      cfg = catalog["difficulty"] || {}
      total_bonus = cfg["base_bonus"].to_i + (wins * cfg["bonus_per_win"].to_i)
      [cfg["base_mastery"].to_i + (total_bonus / 3), total_bonus % 3]
    end

    def reward(wins)
      cfg = catalog["reward"] || {}
      cfg["base_gold"].to_i + (wins * cfg["gold_per_win"].to_i)
    end

    def stake(wins)
      cfg = catalog["stake"] || {}
      cfg["base_gold"].to_i + (wins * cfg["gold_per_win"].to_i)
    end

    # Once the list is exhausted, the last opponent keeps coming back, stronger.
    def opponent_name(game, wins)
      names = game["opponents"] || ["Un habitué"]
      return names[wins] if wins < names.size

      "#{names.last} (revanche n°#{wins - names.size + 2})"
    end

    def skill_roll(character, skill_name)
      skill = character.skills.find_by(name: skill_name)
      skill ? [skill.mastery, skill.bonus] : [character.vigueur, 0]
    end
  end

  def initialize(character)
    @character = character
  end

  def play(key)
    game = self.class.games[key]
    return failure("Jeu inconnu") unless game
    return failure("Vous êtes en combat") if @character.in_combat?
    return failure("Un siège est en cours !") if @character.in_siege?
    return failure("Vous avez déjà joué à ce jeu aujourd'hui, revenez demain") if self.class.played_today?(@character, key)

    wins = self.class.wins(@character, key)
    stake = self.class.stake(wins)
    return failure("Il faut pouvoir miser #{stake} or pour jouer") if @character.gold < stake

    mastery, bonus = self.class.skill_roll(@character, game["skill"])
    opp_mastery, opp_bonus = self.class.opponent_dice(wins)
    duel = DiceRoller.opposed_roll(mastery, bonus, opp_mastery, opp_bonus)
    opponent = self.class.opponent_name(game, wins)

    outcome, gold_change =
      if duel[:margin].positive? then ["victory", self.class.reward(wins)]
      elsif duel[:margin].negative? then ["defeat", -stake]
      else ["draw", 0]
      end

    @character.update!(
      gold: @character.gold + gold_change,
      tavern_games: @character.tavern_games.merge(
        key => { "wins" => wins + (outcome == "victory" ? 1 : 0), "last_day" => @character.absolute_day }
      )
    )

    {
      success: true,
      outcome: outcome,
      gold_change: gold_change,
      gold: @character.gold,
      message: message(game, opponent, duel, outcome, gold_change, mastery, bonus, opp_mastery, opp_bonus),
      game: self.class.game_info(@character, key)
    }
  end

  private

  # rubocop:disable Metrics/ParameterLists
  def message(game, opponent, duel, outcome, gold_change, mastery, bonus, opp_mastery, opp_bonus)
    roll = "#{game['name']} : #{duel[:attack][:total]} (#{DiceRoller.notation(mastery, bonus)}) " \
           "contre #{duel[:defense][:total]} (#{DiceRoller.notation(opp_mastery, opp_bonus)})"
    case outcome
    when "victory" then "#{roll} — vous battez #{opponent} et gagnez #{gold_change} pièces d'or !"
    when "defeat" then "#{roll} — #{opponent} l'emporte, vous perdez votre mise de #{-gold_change} or."
    else "#{roll} — égalité avec #{opponent}, chacun reprend sa mise."
    end
  end
  # rubocop:enable Metrics/ParameterLists

  def failure(error)
    { success: false, error: error }
  end
end
