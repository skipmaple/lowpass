# 整期重生成理由（R-9.6）：覆盖旧理由（R-9.7），异步
class Admin::Issues::ReasonsController < Admin::BaseController
  def create
    issue = Issue.daily.find_by!(period_key: params[:issue_period_key])
    # 画像为空时入队也只是空跑一趟（Generator 会直接 skip），不如当场说清缺的是哪一样
    if Reasons.ready?
      GenerateReasonsJob.perform_later(issue, false)
      Audit.record("issue.regenerate_reasons", "Issue##{issue.period_key}")
      redirect_back_or_to admin_issues_path, notice: "#{issue.period_key} · 已开始重生成理由"
    else
      redirect_back_or_to admin_issues_path, alert: Reasons.unready_label
    end
  end
end
