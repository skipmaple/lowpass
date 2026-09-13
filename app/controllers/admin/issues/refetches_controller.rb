# R-3.10 某期某源重抓：入队手动任务；同一期同一源进行中就不再入队，只提示
class Admin::Issues::RefetchesController < Admin::BaseController
  def create
    issue = Issue.find_by!(period_key: params[:issue_period_key])
    source = refetchable_sources(issue).find { |s| s.id == params[:source_id] } or raise ActiveRecord::RecordNotFound

    unless source.fetch_runs.active.exists?(issue: issue)
      source.fetch_later(issue, trigger: "manual")
      Audit.record("issue.refetch", "Issue##{issue.period_key}", { source_id: source.id, source_name: source.name })
    end
    redirect_back_or_to admin_issues_path, notice: "正在重抓 #{source.name}…"
  end

  private
    # 定稿的期只认它记下的源：日刊定稿时固化（R58），周刊每写一节也记进 source_states（Issue::Weekly#write_section!）。
    # 生成中的期还没固化，按当前启用的同刊物源
    def refetchable_sources(issue)
      if issue.generating?
        Source.enabled.where(publication: issue.kind)
      else
        Source.where(id: issue.source_states.keys)
      end
    end
end
