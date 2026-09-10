class AddSourceStatesToIssues < ActiveRecord::Migration[8.1]
  # source_states 是这一期定稿时各源的结果（source_id → ok / empty / failed）。
  # 抓取记录只保留 30 天（F-26），第 31 天起历史期不能再从 fetch_runs 推导栏目状态。
  def change
    add_column :issues, :source_states, :jsonb, null: false, default: {}

    # 一期的抓取记录按 issue_id 查（source_state、归档的预加载），原来只有 source_id 索引
    add_index :fetch_runs, :issue_id

    add_check_constraint :issues, "kind IN ('daily', 'weekly')", name: "issues_kind"
    add_check_constraint :sources, "adapter IN ('hacker_news', 'github_trending', 'rss', 'ruanyf_weekly')", name: "sources_adapter"
    add_check_constraint :fetch_runs, "status IN ('queued', 'running', 'succeeded', 'failed', 'timed_out')", name: "fetch_runs_status"
    add_check_constraint :fetch_runs, %{"trigger" IN ('scheduled', 'manual', 'test')}, name: "fetch_runs_trigger"

    reversible { |dir| dir.up { backfill_source_states } }
  end

  private
    # 已经定稿的期按库里还剩下的证据回填：有条目就是 ok，没有条目但抓取成功过是 empty，
    # 其余（记录已过期、或真的失败过）是 failed。日刊的栏目清单还要并上当前启用的日刊源，
    # 那些一条都没抓到、抓取记录也清掉了的源才不会从历史期里整栏消失。
    def backfill_source_states
      items = item_source_ids_by_issue
      runs = latest_run_status_by_issue
      daily_source_ids = select_values("SELECT id FROM sources WHERE enabled AND publication = 'daily'")

      select_all("SELECT id, kind FROM issues WHERE state <> 'generating'").each do |issue|
        with_items = items.fetch(issue["id"], [])
        statuses = runs.fetch(issue["id"], {})
        candidates = with_items | statuses.keys
        candidates |= daily_source_ids if issue["kind"] == "daily"

        states = candidates.index_with { |id| backfilled_state(with_items.include?(id), statuses[id]) }
        execute "UPDATE issues SET source_states = #{connection.quote(states.to_json)}::jsonb WHERE id = #{connection.quote(issue["id"])}"
      end
    end

    def backfilled_state(has_items, run_status)
      if has_items
        "ok"
      elsif run_status == "succeeded"
        "empty"
      else
        "failed"
      end
    end

    def item_source_ids_by_issue
      select_all("SELECT DISTINCT issue_id, source_id FROM items")
        .group_by { |row| row["issue_id"] }
        .transform_values { |rows| rows.map { |row| row["source_id"] } }
    end

    def latest_run_status_by_issue
      select_all(<<~SQL.squish)
        SELECT DISTINCT ON (issue_id, source_id) issue_id, source_id, status
        FROM fetch_runs WHERE issue_id IS NOT NULL
        ORDER BY issue_id, source_id, created_at DESC
      SQL
        .group_by { |row| row["issue_id"] }
        .transform_values { |rows| rows.to_h { |row| [ row["source_id"], row["status"] ] } }
    end
end
