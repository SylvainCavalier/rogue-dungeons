class GameCatalog
  CATALOG_PATH = Rails.root.join("config", "catalog")

  class << self
    def equipment(key)
      equipment_index[key]
    end

    def item(key)
      items_index[key]
    end

    def technique(key)
      techniques_index[key]
    end

    def magic(key)
      magics_index[key]
    end

    def floor(number)
      floors_data[number]
    end

    def status_effect(name)
      statuses_index[name]
    end

    def monster(key)
      monsters_index[key]
    end

    def technique_data(key)
      techniques_data_index[key]
    end

    def magic_data(key)
      magics_data_index[key]
    end

    def monster_key_for_name(name)
      name_to_key_map[name]
    end

    # --- Listes complètes ---

    def all_monsters
      @all_monsters ||= load_monsters
    end

    def all_techniques_data
      @all_techniques_data ||= load_techniques_data
    end

    def all_magics_data
      @all_magics_data ||= load_magics_data
    end

    def all_statuses_data
      @all_statuses_data ||= load_statuses_data
    end

    def all_equipment
      @all_equipment ||= load_equipment
    end

    def all_items
      @all_items ||= load_items
    end

    def all_techniques
      @all_techniques ||= load_techniques
    end

    def all_magics
      @all_magics ||= load_magics
    end

    def all_skills
      @all_skills ||= load_skills
    end

    def all_statuses
      @all_statuses ||= load_statuses
    end

    def all_floors
      @all_floors ||= load_floors
    end

    # --- Listes filtrées ---

    def weapons
      all_equipment.select { |e| %w[arme_de_melee arme_a_distance].include?(e["category"]) }
    end

    def armors
      all_equipment.select { |e| e["category"] == "armure" }
    end

    def helmets
      all_equipment.select { |e| e["category"] == "casque" }
    end

    def boots
      all_equipment.select { |e| e["category"] == "bottes" }
    end

    def shields
      all_equipment.select { |e| e["category"] == "bouclier" }
    end

    def shop_equipment
      all_equipment
    end

    def shop_items
      all_items
    end

    def magics_for_element(element)
      all_magics.select { |m| m["element"] == element }.sort_by { |m| m["tier"] }
    end

    def techniques_for_category(category)
      all_techniques.select { |t| t["category"] == category }
    end

    def reload!
      @all_equipment = @all_items = @all_techniques = @all_magics = nil
      @all_skills = @all_statuses = @all_floors = @all_monsters = nil
      @all_techniques_data = @all_magics_data = @all_statuses_data = nil
      @equipment_index = @items_index = @techniques_index = @magics_index = nil
      @statuses_index = @floors_data = @monsters_index = @name_to_key_map = nil
      @techniques_data_index = @magics_data_index = nil
    end

    private

    def equipment_index
      @equipment_index ||= all_equipment.index_by { |e| e["key"] }
    end

    def items_index
      @items_index ||= all_items.index_by { |i| i["key"] }
    end

    def techniques_index
      @techniques_index ||= all_techniques.index_by { |t| t["key"] }
    end

    def magics_index
      @magics_index ||= all_magics.index_by { |m| m["key"] }
    end

    def statuses_index
      @statuses_index ||= all_statuses.index_by { |s| s["name"] }
    end

    def floors_data
      @floors_data ||= all_floors.index_by { |f| f["floor"] }
    end

    def monsters_index
      @monsters_index ||= all_monsters
    end

    def name_to_key_map
      @name_to_key_map ||= begin
        data = YAML.load_file(CATALOG_PATH.join("monstres.yml"))
        data["name_to_key"] || {}
      end
    end

    def techniques_data_index
      @techniques_data_index ||= all_techniques_data
    end

    def magics_data_index
      @magics_data_index ||= all_magics_data
    end

    # --- Chargement ---

    def load_equipment
      data = YAML.load_file(CATALOG_PATH.join("equipement.yml"))
      equipment_data = data["equipment"]
      result = []
      equipment_data.each do |_category_key, items|
        items.each do |item|
          slot = slot_for_category(item["category"])
          result << item.merge("slot" => slot)
        end
      end
      result
    end

    def load_items
      data = YAML.load_file(CATALOG_PATH.join("objets.yaml"))
      items_data = data["items"]
      result = []
      items_data.each do |_category_key, items|
        result.concat(items)
      end
      result
    end

    def load_skills
      content = File.read(CATALOG_PATH.join("competences.md"))
      skills = {}
      current_category = nil

      content.each_line do |line|
        line = line.strip
        if line.start_with?("## ")
          current_category = normalize_category(line.sub("## ", ""))
        elsif line.present? && !line.start_with?("#") && current_category
          skills[line] = current_category
        end
      end
      skills
    end

    def load_techniques
      content = File.read(CATALOG_PATH.join("techniques.md"))
      techniques = []
      current_category = nil

      content.each_line do |line|
        line = line.strip
        if line.start_with?("## ")
          current_category = normalize_technique_category(line.sub("## ", ""))
        elsif line.start_with?("•") && current_category
          name = line.sub(/^[•\t\s]+/, "").strip
          key = name.parameterize(separator: "_")
          techniques << { "key" => key, "name" => name, "category" => current_category }
        end
      end
      techniques
    end

    def load_magics
      content = File.read(CATALOG_PATH.join("magies.md"))
      magics = []
      current_element = nil
      tier = 0

      content.each_line do |line|
        line = line.strip
        if line.start_with?("## ")
          current_element = normalize_category(line.sub("## ", ""))
          tier = 0
        elsif line.start_with?("•") && current_element
          tier += 1
          name = line.sub(/^[•\t\s]+/, "").strip
          key = name.parameterize(separator: "_")
          magics << { "key" => key, "name" => name, "element" => current_element, "tier" => tier }
        end
      end
      magics
    end

    def load_statuses
      content = File.read(CATALOG_PATH.join("statuts.md"))
      statuses = []
      current_type = nil

      content.each_line do |line|
        line = line.strip
        if line.start_with?("## ")
          current_type = line.include?("Négatif") ? "negative" : "positive"
        elsif line.start_with?("•") && current_type
          name = line.sub(/^[•\t\s]+/, "").strip
          statuses << { "name" => name, "type" => current_type }
        end
      end
      statuses
    end

    def load_floors
      content = File.read(CATALOG_PATH.join("tour.md"))
      floors = []
      current_floor = nil

      content.each_line do |line|
        line = line.strip

        if line =~ /^(\d+)\.\s+(.+)$/
          floor_num = ::Regexp.last_match(1).to_i
          enemies_desc = ::Regexp.last_match(2).strip
          enemies = parse_enemies(enemies_desc)
          floors << { "floor" => floor_num, "enemies" => enemies, "boss" => false }
        elsif line =~ /^###?\s+Étage (\d+)\s*[–-]\s*Boss/i
          current_floor = ::Regexp.last_match(1).to_i
        elsif current_floor && line.present? && !line.start_with?("#") && !line.start_with?("•") && !line.start_with?("Thème")
          floors << { "floor" => current_floor, "enemies" => [{ "count" => 1, "name" => line.strip }], "boss" => true }
          current_floor = nil
        end
      end
      floors
    end

    def parse_enemies(desc)
      parts = desc.split("+").map(&:strip)
      parts.map do |part|
        if part =~ /^(\d+)x\s+(.+)$/
          { "count" => ::Regexp.last_match(1).to_i, "name" => ::Regexp.last_match(2).strip }
        else
          { "count" => 1, "name" => part }
        end
      end
    end

    def slot_for_category(category)
      case category
      when "arme_de_melee", "arme_a_distance" then "weapon"
      when "armure" then "armor"
      when "casque" then "helmet"
      when "bottes" then "boots"
      when "bouclier" then "shield"
      end
    end

    def normalize_category(name)
      case name.downcase.strip
      when "vigueur" then "vigueur"
      when "dextérité" then "dexterite"
      when "intelligence" then "intelligence"
      when "charisme" then "charisme"
      when "perception" then "perception"
      when "feu" then "feu"
      when "eau" then "eau"
      when "ombre" then "ombre"
      when "lumière" then "lumiere"
      when "nature" then "nature"
      else name.downcase.parameterize(separator: "_")
      end
    end

    def load_monsters
      data = YAML.load_file(CATALOG_PATH.join("monstres.yml"))
      data["monsters"] || {}
    end

    def load_techniques_data
      data = YAML.load_file(CATALOG_PATH.join("techniques.yml"))
      data["techniques"] || {}
    end

    def load_magics_data
      data = YAML.load_file(CATALOG_PATH.join("magies.yml"))
      data["magics"] || {}
    end

    def load_statuses_data
      data = YAML.load_file(CATALOG_PATH.join("statuts.yml"))
      data["statuses"] || {}
    end

    def normalize_technique_category(name)
      case name.downcase.strip
      when /offensive/ then "offensive"
      when /défensive/, /defensive/ then "defensive"
      when /effet/ then "effect"
      when /avancée/, /avancee/ then "advanced"
      else name.downcase.parameterize(separator: "_")
      end
    end
  end
end
