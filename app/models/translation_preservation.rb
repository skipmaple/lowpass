class TranslationPreservation < ApplicationRecord
  belongs_to :item

  validates :field, inclusion: { in: %w[ title summary ] }
  validates :input_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :assessed_at, presence: true
end
