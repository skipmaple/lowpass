class Issue < ApplicationRecord
  include Issue::Daily, Issue::Weekly, Issue::Sections, Issue::Finalization, Issue::Presenting

  has_many :items, dependent: :delete_all
  has_many :fetch_runs, dependent: :nullify

  validates :kind, inclusion: { in: %w[ daily weekly ] }
  validates :period_key, presence: true
  validates :state, inclusion: { in: %w[ generating published empty ] }

  scope :daily,  -> { where(kind: "daily") }
  scope :weekly, -> { where(kind: "weekly") }
  scope :chronologically, -> { order(:period_key) }

  def published? = state == "published"
  def empty?     = state == "empty"
  def generating? = state == "generating"
end
