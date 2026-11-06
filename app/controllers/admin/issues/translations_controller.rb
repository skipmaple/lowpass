class Admin::Issues::TranslationsController < Admin::BaseController
  before_action :set_issue

  def new
    render json: Translations::Preview.issue(@issue, user: Current.user, reassess: params[:reassess] == "true")
  end

  def create
    return redirect_back_or_to(admin_issues_path, alert: Translations.unready_label) unless Translations.ready?

    payload = Translations::Preview.verify(params[:token], issue: @issue, user: Current.user)
    return redirect_back_or_to(admin_issues_path, alert: "没有需要补全的译文") if payload.fetch("targets").empty?

    GenerateTranslationsJob.perform_later(@issue, payload)
    Audit.record("issue.complete_translations", "Issue##{@issue.period_key}", operation_key: payload.fetch("operation").fetch("key"),
      target_count: payload.fetch("targets").size, reassess: payload.fetch("reassess"))
    redirect_back_or_to admin_issues_path, notice: "已提交译文补全任务，刷新查看结果"
  rescue Translations::Preview::Invalid => e
    redirect_back_or_to admin_issues_path, alert: e.message
  end

  private
    def set_issue
      @issue = Issue.daily.where(state: "published").find_by!(period_key: params[:issue_period_key])
      raise ActiveRecord::RecordNotFound unless @issue.items.visible.exists?
    end
end
