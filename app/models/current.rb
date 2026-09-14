# 请求期间的上下文（工程约定「认证、会话与请求上下文」）：会话与用户由 Authentication 填，请求属性由 ApplicationController 填
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :request_id, :ip_address, :user_agent
  delegate :user, to: :session, allow_nil: true

  def admin? = user&.admin? || false
end
