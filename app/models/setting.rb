class Setting < ApplicationRecord
  DEFAULTS = { "daily_time" => "06:00", "weekly_time" => "09:00", "weekly_checked_on" => "" }.freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key: key)&.value || DEFAULTS.fetch(key)
  end

  def self.set(key, value)
    find_or_initialize_by(key: key).update!(value: value)
  end
end
