class Setting < ApplicationRecord
  DEFAULTS = { "daily_time" => "06:00", "weekly_time" => "09:00", "weekly_checked_on" => "", "cleaned_on" => "" }.freeze
  TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/

  validates :key, presence: true, uniqueness: true

  # 后台改调度时间（R-1.1 精确到分）：只认 HH:MM
  def self.valid_time?(value)
    value.to_s.match?(TIME)
  end

  # 存了空串跟没存一样：管理员把生成时间清空后，调度不该拿着 "" 去 split(":")
  def self.get(key)
    find_by(key: key)&.value.presence || DEFAULTS.fetch(key)
  end

  def self.set(key, value)
    find_or_initialize_by(key: key).update!(value: value)
  end
end
