# 与 Item 同寿命的最后一次合法拒写；不 touch 已发布条目或刊期。
class ReasonAbstention < ApplicationRecord
  belongs_to :item

  validates :assessed_at, presence: true
end
