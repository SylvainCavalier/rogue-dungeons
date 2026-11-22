class Character < ApplicationRecord
  belongs_to :user
  has_many :skills, dependent: :destroy
  has_many :inventory_items, dependent: :destroy
  has_many :learned_techniques, dependent: :destroy
  has_many :learned_magics, dependent: :destroy
  has_many :combat_logs, dependent: :destroy
  has_many :fortress_defenses, dependent: :destroy
  has_many :town_defenders, dependent: :destroy
  has_many :siege_logs, dependent: :destroy
  has_many :monster_knowledges, dependent: :destroy

  CHARACTERISTICS = %w[vigueur dexterite intelligence charisme perception].freeze
  TOTAL_POINTS = 12
  MIN_PER_STAT = 1
  MAX_PER_STAT = 4
  DAYS_PER_WEEK = 7
  WEEKS_PER_MONTH = 4
  MONTHS_PER_YEAR = 12

  SKILLS_MAP = {
    "vigueur" => %w[Endurance Escalade Natation Bras\ de\ fer Résistance\ à\ l'alcool Forge],
    "dexterite" => %w[Arc Arme\ à\ une\ main Arme\ à\ deux\ mains Esquive Discrétion Vitesse Parade],
    "intelligence" => %w[Feu Eau Ombre Lumière Nature Invocation Enchantement Alchimie],
    "charisme" => %w[Persuasion Marchandage Dressage],
    "perception" => %w[Intuition Observation Sang-Froid Fouille]
  }.freeze

  DEFENSE_MODES = %w[esquive parade].freeze

  # Skills kept in the database but hidden from the player until they get a use
  # (see CLAUDE.md, "Hidden skills").
  HIDDEN_SKILLS = %w[Discrétion].freeze

  validates :name, presence: true
  validates :defense_mode, inclusion: { in: DEFENSE_MODES }
  validates :vigueur, :dexterite, :intelligence, :charisme, :perception,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: MIN_PER_STAT }
  validates :vigueur, :dexterite, :intelligence, :charisme, :perception,
            numericality: { only_integer: true, less_than_or_equal_to: MAX_PER_STAT },
            on: :create
  validate :total_characteristics_must_equal_twelve, on: :create

  before_validation :compute_derived_stats
  after_create :initialize_skills

  # --- Marchandage ---

  # Each skill step above 1D (an upgrade = 1 step, a die = 3 steps) gives
  # HAGGLE_PERCENT_PER_STEP % off purchases and on top of resale prices, capped.
  # Buying stays dearer than reselling (sell = half price), so no gold loop.
  HAGGLE_PERCENT_PER_STEP = 2
  HAGGLE_MAX_PERCENT = 30
  DAMAGED_SHOP_SURCHARGE = 1.25

  def haggle_dice
    skill = skills.find_by(name: "Marchandage")
    skill ? [skill.mastery, skill.bonus] : [charisme, 0]
  end

  def haggle_percent
    mastery, bonus = haggle_dice
    (((mastery - 1) * 3 + bonus) * HAGGLE_PERCENT_PER_STEP).clamp(0, HAGGLE_MAX_PERCENT)
  end

  # Unit price paid in a town shop (forge, shop, apothecary): a damaged building
  # charges more, then Marchandage lowers it.
  def buy_price(base_price, building)
    price = base_price.to_f
    price *= DAMAGED_SHOP_SURCHARGE if building_damaged?(building)
    [(price * (100 - haggle_percent) / 100.0).ceil, 1].max
  end

  # Unit price received when selling an item (its base sell price + Marchandage).
  def sell_price_for(item)
    (item.sell_price * (100 + haggle_percent) / 100.0).floor
  end

  def haggle_info
    mastery, bonus = haggle_dice
    { notation: DiceRoller.notation(mastery, bonus), percent: haggle_percent }
  end

  # --- Travail ---

  # Dice used when working at the forge: the Forge skill, falling back to Vigueur.
  def forge_roll
    skill = skills.find_by(name: "Forge")
    skill ? [skill.mastery, skill.bonus] : [vigueur, 0]
  end

  # Dice used when working at the apothecary: the Alchimie skill, falling back to Intelligence.
  def alchemy_roll
    skill = skills.find_by(name: "Alchimie")
    skill ? [skill.mastery, skill.bonus] : [intelligence, 0]
  end

  # Dice for a day of work at the given workplace ("forge" or "apothecary").
  def work_roll(place)
    place == "apothecary" ? alchemy_roll : forge_roll
  end

  # --- Défense ---

  # A ranged weapon can't parry: the player always dodges with one equipped.
  def can_parry?
    weapon = equipped_weapon
    weapon.nil? || weapon.catalog_data&.dig("category") != "arme_a_distance"
  end

  # Defense mode actually used in combat (the saved choice, unless parry is impossible).
  def effective_defense_mode
    defense_mode == "parade" && can_parry? ? "parade" : "esquive"
  end

  # Base dice of the chosen defense skill ("Esquive" or "Parade"), falling back to Dextérité.
  # Equipment adds a flat bonus to the matching mode (boots: esquive_bonus, helmets: parade_bonus).
  def defense_roll(mode = effective_defense_mode)
    skill = skills.find_by(name: mode == "parade" ? "Parade" : "Esquive")
    mastery, bonus = skill ? [skill.mastery, skill.bonus] : [dexterite, 0]
    ench_m, ench_b = enchantment_dice(mode == "parade" ? "parade" : "esquive")
    [mastery + ench_m, bonus + ench_b + equipment_bonus(mode == "parade" ? "parade_bonus" : "esquive_bonus")]
  end

  # --- Temps ---

  def advance_day(n = 1)
    siege_triggered = false
    n.times do
      self.day += 1
      if day > DAYS_PER_WEEK
        self.day = 1
        trigger_siege_preparation unless siege_triggered
        siege_triggered = true
        self.week += 1
        if week > WEEKS_PER_MONTH
          self.week = 1
          self.month += 1
          if month > MONTHS_PER_YEAR
            self.month = 1
            self.year += 1
          end
        end
      end
      tick_status
      tick_activity
    end
    save!
    siege_triggered
  end

  # Days elapsed since the start of the game (1 = first day), used for daily limits.
  def absolute_day
    ((((year - 1) * MONTHS_PER_YEAR * WEEKS_PER_MONTH) + ((month - 1) * WEEKS_PER_MONTH) + (week - 1)) * DAYS_PER_WEEK) + day
  end

  def formatted_date
    "Jour #{day}, Semaine #{week}, Mois #{month}, Année #{year}"
  end

  # --- État ---

  def alive?
    current_hp.positive?
  end

  def full_heal
    update!(current_hp: max_hp, current_mana: max_mana)
  end

  def in_combat?
    combat_state.present?
  end

  def in_siege?
    siege_state.present?
  end

  def siege_pending?
    siege_state.is_a?(Hash) && siege_state["pending"] == true
  end

  def building_damaged?(building_key)
    (building_damage[building_key] || 0) > 0
  end

  def building_destroyed?(building_key)
    (building_damage[building_key] || 0) >= 2
  end

  def total_weeks_elapsed
    ((year - 1) * MONTHS_PER_YEAR * WEEKS_PER_MONTH) + ((month - 1) * WEEKS_PER_MONTH) + week
  end

  def busy?
    activity.present? && activity_days_left&.positive?
  end

  # --- Équipement porté ---

  def equipped_weapon
    inventory_items.find_by(equipped: true, slot: "weapon")
  end

  def equipped_armor
    inventory_items.find_by(equipped: true, slot: "armor")
  end

  def equipped_helmet
    inventory_items.find_by(equipped: true, slot: "helmet")
  end

  def equipped_boots
    inventory_items.find_by(equipped: true, slot: "boots")
  end

  def equipped_shield
    inventory_items.find_by(equipped: true, slot: "shield")
  end

  # Equipment DR, including the "Protection" enchantments (armor, shield).
  def total_dr_mastery
    %w[armor helmet boots shield].sum do |slot|
      item = inventory_items.find_by(equipped: true, slot: slot)
      item ? catalog_for(item)&.dig("dr_mastery").to_i : 0
    end + enchantment_dice("protection")[0]
  end

  def total_dr_bonus
    %w[armor helmet boots shield].sum do |slot|
      item = inventory_items.find_by(equipped: true, slot: slot)
      item ? catalog_for(item)&.dig("dr_bonus").to_i : 0
    end + enchantment_dice("protection")[1]
  end

  # --- Enchantements ---

  # Enchantment skill dice (fallback Intelligence).
  def enchantment_roll
    skill = skills.find_by(name: "Enchantement")
    skill ? [skill.mastery, skill.bonus] : [intelligence, 0]
  end

  # Resolved enchantments of the equipped items (see InventoryItem#enchantment_effect).
  def equipped_enchantments
    inventory_items.where(equipped: true).where.not(enchantment: nil).filter_map(&:enchantment_effect)
  end

  # [mastery, bonus] summed over the equipped items enchanted with this effect.
  def enchantment_dice(effect_key)
    matching = equipped_enchantments.select { |e| e[:key] == effect_key }
    [matching.sum { |e| e[:mastery] }, matching.sum { |e| e[:bonus] }]
  end

  def enchantment_percent(effect_key)
    equipped_enchantments.select { |e| e[:key] == effect_key }.sum { |e| e[:percent] }
  end

  # Elemental enchantment of the equipped weapon ({ key: "feu", mastery:, bonus:, … }) or nil.
  def weapon_enchantment
    equipped_weapon&.enchantment_effect
  end

  # Passive item (effect_type "passive") carried in the inventory, e.g. "no_ambush".
  def passive_item(passive_key)
    inventory_items.where(item_type: "item").find do |item|
      data = catalog_for(item)
      data && data["effect_type"] == "passive" && data["passive"] == passive_key
    end&.then { |item| catalog_for(item) }
  end

  # Sum of a catalog field over equipped items (esquive_bonus, parade_bonus, flee_bonus, speed_bonus…).
  def equipment_bonus(field)
    inventory_items.where(equipped: true).sum { |item| catalog_for(item)&.dig(field).to_i }
  end

  # Initiative (Vitesse skill + boots speed_bonus), rolled once per combat.
  def initiative_roll
    skill = skills.find_by(name: "Vitesse")
    mastery, bonus = skill ? [skill.mastery, skill.bonus] : [dexterite, 0]
    ench_m, ench_b = enchantment_dice("vitesse")
    [mastery + ench_m, bonus + ench_b + equipment_bonus("speed_bonus")]
  end

  def total_accuracy_bonus_from_equipment
    %w[weapon armor helmet boots shield].sum do |slot|
      item = inventory_items.find_by(equipped: true, slot: slot)
      item ? catalog_for(item)&.dig("accuracy_bonus").to_i : 0
    end
  end

  # --- Magie ---

  ELEMENT_SKILLS = { "feu" => "Feu", "eau" => "Eau", "ombre" => "Ombre", "lumiere" => "Lumière",
                     "nature" => "Nature", "invocation" => "Invocation" }.freeze

  # Flat bonus added to damage spells: +1 per 2 dice of the element skill (fallback Intelligence).
  def spell_power(element)
    skill = skills.find_by(name: ELEMENT_SKILLS[element.to_s])
    (skill ? skill.mastery : intelligence) / 2
  end

  # Invocation skill dice (fallback Intelligence): sets the strength of summoned creatures.
  def invocation_mastery
    skill = skills.find_by(name: "Invocation")
    skill ? skill.mastery : intelligence
  end

  # --- Upgrades XP -> PV/PM ---

  def hp_upgrade_cost
    self.class.stat_upgrade_cost(max_hp)
  end

  def mana_upgrade_cost
    self.class.stat_upgrade_cost(max_mana)
  end

  def self.stat_upgrade_cost(current_max)
    current_max < 20 ? 1 : current_max / 10
  end

  private

  def compute_derived_stats
    return unless vigueur.present? && intelligence.present?

    self.max_hp = (vigueur * 3) + (bonus_max_hp || 0)
    self.current_hp = max_hp if current_hp.nil? || new_record?
    self.max_mana = (intelligence * 3) + (bonus_max_mana || 0)
    self.current_mana = max_mana if current_mana.nil? || new_record?
  end

  def total_characteristics_must_equal_twelve
    total = [vigueur, dexterite, intelligence, charisme, perception].compact.sum
    errors.add(:base, "La somme des caractéristiques doit être égale à #{TOTAL_POINTS}") unless total == TOTAL_POINTS
  end

  def initialize_skills
    SKILLS_MAP.each do |category, skill_names|
      base_mastery = send(category)
      skill_names.each do |skill_name|
        skills.create!(name: skill_name, category: category, mastery: base_mastery, bonus: 0)
      end
    end
  end

  def trigger_siege_preparation
    self.siege_state = {
      "pending" => true,
      "siege_week" => total_weeks_elapsed + 1
    }
  end

  def tick_status
    return unless status.present? && status_duration.present?

    self.status_duration -= 1
    if status_duration <= 0
      self.status = nil
      self.status_duration = 0
    end
  end

  def tick_activity
    return unless activity.present? && activity_days_left.present?

    self.activity_days_left -= 1
    if activity_days_left <= 0
      self.activity = nil
      self.activity_days_left = 0
    end
  end

  def catalog_for(inventory_item)
    case inventory_item.item_type
    when "equipment"
      GameCatalog.equipment(inventory_item.item_key)
    when "item"
      GameCatalog.item(inventory_item.item_key)
    end
  end
end
