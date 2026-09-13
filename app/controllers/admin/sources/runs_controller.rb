# R-3.9 抓取记录：最近 50 次、按状态筛选；右上角重抓最新一期（R-3.10）
class Admin::Sources::RunsController < Admin::BaseController
  STATUSES = %w[ all succeeded failed ].freeze

  def index
    source = Source.find(params[:source_id])
    status = params[:status].presence_in(STATUSES) || "all"
    runs = FetchRun.manual_run_props(source.fetch_runs.manual_recent)
    render inertia: "Admin/Sources/Runs", props: {
      source: { id: source.id, name: source.name, adapter_label: source.adapter_label, publication: source.publication },
      status: status,
      runs: source.run_rows(status),
      latest_issue: latest_issue(source),
      active_runs: runs[:active],
      finished_runs: runs[:finished]
    }
  end

  private
    def latest_issue(source)
      if source.publication == "daily"
        key = Issue.daily.maximum(:period_key)
        key && { period_key: key, label: PeriodKey.date_label(PeriodKey.date_of(key)) }
      else
        key = Issue.weekly.maximum(:period_key)
        key && { period_key: key, label: "第 #{PeriodKey.week_number(key)} 周" }
      end
    end
end
