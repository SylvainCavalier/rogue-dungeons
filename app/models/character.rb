class Character < ApplicationRecord
  belongs_to :user
  has_many :skills, dependent: :destroy
  has_many :inventory_items, dependent: :destroy
  has_many :learned_techniques, dependent: :destroy
  has_many :learned_magics, dependent: :destroy
  has_many :combat_logs, dependent: :destroy

  CHARACTERISTICS = %w[vigueur dexterite intelligence charisme perception].freeze
  TOTAL_POINTS = 12
  MIN_PER_STAT = 1
  MAX_PER_STAT = 8
  DAYS_PER_WEEK = 7
  WEEKS_PER_MONTH = 4
  MONTHS_PER_YEAR = 12

  SKILLS_MAP = {
    "vigueur" => %w[Endurance Escalade Natation Bras\ de\ fer Résistance\ à\ l'alcool],
    "dexterite" => %w[Arc Arme\ à\ une\ main Arme\ à\ deux\ mains Esquive Discrétion Vitesse Parade],
    "intelligence" => %w[Feu Eau Ombre Lumière Nature Enchantement Alchimie],
    "charisme" => %w[Persuasion Marchandage Dressage],
    "perception" => %w[Intuition Observation Sang-Froid Fouille]
  }.freeze

  validates :name, presence: true
  validates :vigueur, :dexterite, :intelligence, :charisme, :perception,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: MIN_PER_STAT, less_than_or_equal_to: MAX_PER_STAT }
  validate :total_characteristics_must_equal_twelve, on: :create

  before_validation :compute_derived_stats
  after_create :initialize_skills

  # --- Temps ---

  def advance_day(n = 1)
    n.times do
      self.day += 1
      if day > DAYS_PER_WEEK
        self.day = 1
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

  def total_dr_mastery
    %w[armor helmet boots shield].sum do |slot|
      item = inventory_items.find_by(equipped: true, slot: slot)
      item ? catalog_for(item)&.dig("dr_mastery").to_i : 0
    end
  end

  def total_dr_bonus
    %w[armor helmet boots shield].sum do |slot|
      item = inventory_items.find_by(equipped: true, slot: slot)
      item ? catalog_for(item)&.dig("dr_bonus").to_i : 0
    end
  end

  def total_accuracy_bonus_from_equipment
    %w[weapon armor helmet boots shield].sum do |slot|
      item = inventory_items.find_by(equipped: true, slot: slot)
      item ? catalog_for(item)&.dig("accuracy_bonus").to_i : 0
    end
  end

  private

  def compute_derived_stats
    return unless vigueur.present? && intelligence.present?

    self.max_hp = vigueur * 3
    self.current_hp = max_hp if current_hp.nil? || new_record?
    self.max_mana = intelligence * 3
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
