require "test_helper"

# 后台信息源列表（R-3.1）：健康度、上次抓取、下次计划都从已有记录与设置推导
class Source::PresentingTest < ActiveSupport::TestCase
  test "admin_rows 按排序值列全部源，含停用的" do
    sources(:ruanyf).update!(enabled: false)

    rows = travel_to(Time.utc(2026, 9, 8, 0, 0)) { Source.admin_rows }

    assert_equal [ "Hacker News", "GitHub Trending", "Hackaday", "阮一峰科技爱好者周刊" ], rows.map { |row| row[:name] }
    hn = rows.first
    assert_equal "Hacker News", hn[:adapter_label]
    assert_equal "正常", hn[:health_label]
    assert_equal "9月8日 06:00 · 成功 · 10 条", hn[:last_fetch_label]
    # Time.utc(2026, 9, 8, 0, 0) 是上海 9月8日 08:00：当天 06:00 已过，下一次是明天
    assert_equal "9月9日 06:00", hn[:next_run_label]
    ruanyf = rows.last
    assert_equal "已停用", ruanyf[:health_label]
    assert_nil ruanyf[:next_run_label]
  end

  test "下次计划：还没到今天的生成时间就是今天" do
    row = travel_to(Time.utc(2026, 9, 7, 20, 30)) { Source.admin_rows.first }   # 上海 04:30

    assert_equal "9月8日 06:00", row[:next_run_label]
  end

  test "上次抓取只看调度与手动的记录，失败带错误摘要，没有就是尚未抓取" do
    sources(:hn).fetch_runs.create!(trigger: "test", attempt: 1, status: "failed", started_at: Time.current, error_summary: "x")
    sources(:github).fetch_runs.create!(issue: issues(:daily_0908), trigger: "scheduled", attempt: 3, status: "timed_out", started_at: Time.utc(2026, 9, 8, 22, 5), error_summary: "连接超时")

    rows = Source.admin_rows.index_by { |row| row[:name] }

    assert_equal "9月8日 06:00 · 成功 · 10 条", rows["Hacker News"][:last_fetch_label]
    assert_equal "9月9日 06:05 · 超时 · 连接超时", rows["GitHub Trending"][:last_fetch_label]
    assert_equal "尚未抓取", rows["阮一峰科技爱好者周刊"][:last_fetch_label]
  end

  test "form_props 与 adapter_options" do
    props = sources(:hackaday).form_props
    assert_equal({ id: sources(:hackaday).id, name: "Hackaday", adapter: "rss", publication: "daily", sort_order: 3,
                   config: { "feed_url" => "https://hackaday.com/feed/", "count" => 10, "window_hours" => 24 } }, props)

    options = Source.adapter_options
    assert_equal %w[ hacker_news github_trending rss ruanyf_weekly ], options.map { |o| o[:key] }
    assert_equal %w[ daily weekly ], options.find { |o| o[:key] == "rss" }[:publications]
  end

  # 新建表单的名称必须是 ""：React 受控输入框拿到 null 会当成非受控，再填就不受控了
  test "form_props 的名称是空串，不是 nil" do
    assert_equal "", Source.new(adapter: "rss", publication: "daily", sort_order: 1).form_props[:name]
  end

  test "run_rows 最近 50 条、按状态筛选" do
    60.times { |i| sources(:hn).fetch_runs.create!(trigger: "scheduled", attempt: 1, status: i.even? ? "succeeded" : "failed", started_at: i.hours.ago, item_count: 10, error_summary: (i.odd? ? "boom" : nil)) }

    assert_equal 50, sources(:hn).run_rows("all").size
    assert sources(:hn).run_rows("failed").all? { |row| row[:status] == "failed" }
    assert sources(:hn).run_rows("succeeded").all? { |row| row[:status] == "succeeded" }
    row = sources(:hn).run_rows("all").first
    assert_match(/\A\d+月\d+日 \d{2}:\d{2}:\d{2}\z/, row[:started_label])
    assert_equal "1 / 3", row[:attempt_label]
  end

  test "manual_run_props 分成进行中与刚结束" do
    running = sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "running", started_at: Time.current)
    done = sources(:github).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "failed", started_at: Time.current, error_summary: "连接超时")

    props = FetchRun.manual_run_props(FetchRun.manual_recent)

    assert_equal [ { id: running.id, source_name: "Hacker News", period_key: "2026-09-08" } ], props[:active]
    assert_equal [ { id: done.id, source_name: "GitHub Trending", status: "failed", item_count: nil, error_summary: "连接超时" } ], props[:finished]
  end
end
