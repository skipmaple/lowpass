# 控制器在写操作成功后调一次。审计是记账：写失败只报告，不让管理员的操作跟着失败（设计 A10）
module Audit
  def self.record(action, target, payload = {})
    AuditLog.create!(user: Current.user, action: action, target: target, payload: payload)
  rescue StandardError => e
    Rails.error.report(e, handled: true)
    nil
  end
end
