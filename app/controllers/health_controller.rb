# N-5 健康检查（设计 §3、E11、E13）：给外部拨测，只有状态没有内容，所以不走登录墙（D1 不受影响）。
# 继承 ActionController::Base，与 Rails 自带的 /up 同款，不经 ApplicationController 的登录、Inertia 与浏览器版本检查；
# /up 仍给 kamal-proxy。限流计数放进程内存：放 Solid Cache 的话，数据库挂了这里会先 500，拨测就看不到哪一项坏了
class HealthController < ActionController::Base
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE

  def show
    report = Health.check
    render json: report, status: report.ok? ? :ok : :service_unavailable
  end
end
