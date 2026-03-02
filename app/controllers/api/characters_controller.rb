module Api
  class CharactersController < BaseController
    before_action :require_character!, only: [:show, :stats]

    def show
      render json: character_full(current_character)
    end

    def create
      if current_user.character.present?
        return render json: { error: "Vous avez déjà un personnage" }, status: :unprocessable_entity
      end

      character = current_user.build_character(character_params)

      if character.save
        render json: character_full(character), status: :created
      else
        render json: { errors: character.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def stats
      char = current_character
      skills_by_category = char.skills.order(:name).group_by(&:category)

      render json: {
        characteristics: {
          vigueur: char.vigueur,
          dexterite: char.dexterite,
          intelligence: char.intelligence,
          charisme: char.charisme,
          perception: char.perception
        },
        hp: { current: char.current_hp, max: char.max_hp },
        mana: { current: char.current_mana, max: char.max_mana },
        xp: char.xp,
        gold: char.gold,
        status: char.status,
        status_duration: char.status_duration,
        skills: skills_by_category.transform_values { |skills|
          skills.map { |s| skill_json(s) }
        },
        equipment: equipped_json(char)
      }
    end

    private

    def character_params
      params.require(:character).permit(:name, :vigueur, :dexterite, :intelligence, :charisme, :perception)
    end

    def character_full(char)
      {
        id: char.id,
        name: char.name,
        vigueur: char.vigueur,
        dexterite: char.dexterite,
        intelligence: char.intelligence,
        charisme: char.charisme,
        perception: char.perception,
        current_hp: char.current_hp,
        max_hp: char.max_hp,
        current_mana: char.current_mana,
        max_mana: char.max_mana,
        xp: char.xp,
        gold: char.gold,
        current_floor: char.current_floor,
        date: char.formatted_date,
        day: char.day,
        week: char.week,
        month: char.month,
        year: char.year,
        status: char.status,
        status_duration: char.status_duration,
        activity: char.activity,
        activity_days_left: char.activity_days_left,
        activity_data: char.activity_data,
        in_combat: char.in_combat?,
        skills: char.skills.order(:category, :name).map { |s| skill_json(s) },
        techniques: char.learned_techniques.map { |t| { id: t.id, key: t.technique_key, name: t.name, category: t.category } },
        magics: char.learned_magics.order(:element, :tier).map { |m| { id: m.id, key: m.magic_key, name: m.name, element: m.element, tier: m.tier } },
        equipment: equipped_json(char)
      }
    end

    def skill_json(skill)
      {
        id: skill.id,
        name: skill.name,
        category: skill.category,
        mastery: skill.mastery,
        bonus: skill.bonus,
        notation: skill.notation,
        upgrade_cost: skill.upgrade_cost
      }
    end

    def equipped_json(char)
      equipped = {}
      %w[weapon armor helmet boots shield].each do |slot|
        item = char.inventory_items.find_by(equipped: true, slot: slot)
        if item
          catalog = item.catalog_data
          equipped[slot] = {
            id: item.id,
            item_key: item.item_key,
            name: catalog&.dig("name") || item.item_key,
            data: catalog
          }
        end
      end
      equipped
    end
  end
end
