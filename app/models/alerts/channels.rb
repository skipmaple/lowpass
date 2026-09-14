# 渠道注册表：配了哪个就发哪个（R-7.3「配置其一或两者」）
module Alerts::Channels
  def self.all = [ Email, Webhook ]
  def self.configured = all.select(&:configured?)
end
