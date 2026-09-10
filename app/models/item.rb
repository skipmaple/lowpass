class Item < ApplicationRecord
  belongs_to :source
  belongs_to :issue

  validates :title, presence: true, length: { maximum: 300 }
  validates :url, presence: true, length: { maximum: 2048 }, format: { with: %r{\Ahttps?://\S+\z}i }
  validates :url_hash, presence: true, length: { is: 64 }
  validates :summary, length: { maximum: 500 }, allow_nil: true

  scope :visible, -> { where(hidden: false) }
  scope :ranked,  -> { order(:rank, :created_at) }
end
