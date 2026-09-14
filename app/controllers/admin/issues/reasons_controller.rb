# 整期重生成理由（R-9.6）：覆盖旧理由（R-9.7），异步
class Admin::Issues::ReasonsController < Admin::BaseController
  def create
    issue = Issue.daily.find_by!(period_key: params[:issue_period_key])
    if Reasons::Provider.configured?
      GenerateReasonsJob.perform_later(issue, false)
      Audit.record("issue.regenerate_reasons", "Issue##{issue.period_key}")
      redirect_back_or_to admin_issues_path, notice: "已开始重生成理由"
    else
      redirect_back_or_to admin_issues_path, alert: "未配置模型供应商"
    end
  end
end
