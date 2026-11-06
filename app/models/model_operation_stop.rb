# 终止事实不是一次模型请求，不能伪造一条 ModelCall 来保存。
class ModelOperationStop < ApplicationRecord
  REASONS = %w[ budget rejected limited ].freeze

  validates :operation_key, presence: true, length: { maximum: 36 }
  validates :reason, inclusion: { in: REASONS }
  validates :expires_at, presence: true
end
