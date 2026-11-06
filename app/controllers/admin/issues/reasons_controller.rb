# 整期重生成理由（R-9.6）：覆盖旧理由（R-9.7），异步
class Admin::Issues::ReasonsController < Admin::BaseController
  def create
    issue = Issue.daily.find_by!(period_key: params[:issue_period_key])
    # 画像为空时入队也只是空跑一趟（Generator 会直接 skip），不如当场说清缺的是哪一样
    if Reasons.ready?
      # 同一期的并发请求串行检查，避免一次长推理期间多次点击排起整期重复任务。
      result = issue.with_lock do
        if Reasons::Progress.active?(issue)
          :active
        elsif GenerateReasonsJob.perform_later(issue, false)
          Audit.record("issue.regenerate_reasons", "Issue##{issue.period_key}")
          :queued
        else
          :failed
        end
      end
      if result == :failed
        redirect_back_or_to admin_issues_path, alert: "理由任务未能入队，请重试。"
      else
        message = result == :queued ? "理由任务已排队，进度会自动更新" : "理由任务已在处理中，请等待进度更新"
        redirect_back_or_to admin_issues_path, notice: "#{issue.period_key} · #{message}"
      end
    else
      redirect_back_or_to admin_issues_path, alert: Reasons.unready_label
    end
  end
end
