# 期（5.6）：一页一个月；重抓、补生成、立即生成各是自己的资源
class Admin::IssuesController < Admin::BaseController
  KINDS = %w[ all daily weekly ].freeze

  def index
    kind = params[:kind].presence_in(KINDS) || "all"
    if listing = listing_for(kind)
      runs = FetchRun.manual_run_props(FetchRun.manual_recent)
      render inertia: "Admin/Issues/Index", props: listing.merge(
        kind: kind,
        today_issue_exists: Issue.daily.exists?(period_key: PeriodKey.today),
        active_runs: runs[:active],
        finished_runs: runs[:finished]
      )
    else
      render_not_found
    end
  end

  private
    # ?month[]=… 让 params[:month] 变成 Array：Date.strptime 抛的是 TypeError，不是 admin_rows
    # 接得住的 Date::Error。形状不对就跟越界的月份一样落 404（日刊归档同样挡过这一手，
    # DailyIssuesController#requested_month）
    def listing_for(kind)
      month = params[:month]
      Issue.admin_rows(kind: kind, month: month.presence) if month.nil? || month.is_a?(String)
    end
end
