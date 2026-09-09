class Source < ApplicationRecord
  ADAPTERS = %w[ hacker_news github_trending rss ruanyf_weekly ].freeze

  has_many :items, dependent: :restrict_with_exception
  has_many :fetch_runs, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }
  validates :adapter, inclusion: { in: ADAPTERS }
  validates :publication, inclusion: { in: %w[ daily weekly ] }

  scope :enabled, -> { where(enabled: true) }
  scope :daily,   -> { where(publication: "daily") }
  scope :weekly,  -> { where(publication: "weekly") }
  scope :ordered, -> { order(:sort_order, :name) }

  def adapter_class
    "Adapters::#{adapter.camelize}".constantize
  end
end
