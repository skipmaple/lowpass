# R-7.4 后台「发送测试告警」：验证渠道能收到；一次一封，每分钟 5 次（设计 B12）
class Admin::TestAlertsController < Admin::BaseController
  rate_limit to: 5, within: 1.minute, by: -> { Current.user.id }, with: -> { redirect_to admin_settings_path, alert: "操作过于频繁，请稍后再试。" }

  # 门面建记录或入队失败时返回 nil（B10：告警不抛给调用方），这里也就没有事件可审计
  def create
    if !Alerts.configured?
      redirect_to admin_settings_path, alert: "告警渠道未配置"
    elsif (event = Alerts.test!(Current.user))
      Audit.record("alert.test", "AlertEvent##{event.id}")
      redirect_to admin_settings_path, notice: "已发送测试告警"
    else
      redirect_to admin_settings_path, alert: "测试告警没有发出，请查看日志"
    end
  end
end
