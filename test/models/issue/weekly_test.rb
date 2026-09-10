require "test_helper"

class Issue::WeeklyTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ]) }

  def entries(n, section: "科技动态", published: Time.utc(2026, 9, 4), meta: { issue_no: 367, issue_title: "主题" }, offset: 0)
    (1..n).map { |i| Adapters::Entry.new(title: "t#{i}", url: "https://x/#{i + offset}", section: section, published_at: published, rank: i, meta: meta) }
  end

  def rss_weekly_source(sort_order: 2)
    Source.create!(name: "W", adapter: "rss", publication: "weekly", sort_order: sort_order, config: { feed_url: "https://w.example/feed" })
  end

  test "AC-2.1 新期归入发布日所在 ISO 周" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).with(367).returns(entries(6, published: Time.utc(2026, 9, 11)))
    Issue.check_weekly_sources!
    issue = Issue.weekly.find_by!(period_key: "2026-W37")
    assert_equal 6, issue.items.count
    assert issue.published?
  end

  test "AC-2.2 少于 5 条降级为整期一条" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    err = Adapters::RuanyfWeekly::Degraded.new("x").tap { |e| e.issue_no = 367; e.issue_title = "坏了"; e.url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-367.md" }
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).raises(err)
    Issue.check_weekly_sources!
    item = Issue.weekly.order(:period_key).last.items.sole
    assert item.meta["degraded"]
    assert_equal err.url, item.url
  end

  test "降级期次日重试并替换整期一条" do
    travel_to Time.utc(2026, 9, 10, 4, 0) do
      Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
      err = Adapters::RuanyfWeekly::Degraded.new("x").tap { |e| e.issue_no = 367; e.issue_title = "坏了"; e.url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-367.md" }
      Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).raises(err)
      Issue.check_weekly_sources!

      Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).returns(entries(6, published: Time.utc(2026, 9, 11)))
      Issue.check_weekly_sources!

      items = Issue.weekly.find_by!(period_key: "2026-W37").items.where(source: sources(:ruanyf))
      assert_equal 6, items.count
      assert items.none? { |i| i.meta["degraded"] }
    end
  end

  test "AC-2.6 上周五的期本周一才检测到，仍归上周" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).returns(entries(6, published: Time.utc(2026, 9, 4)))
    travel_to Time.utc(2026, 9, 7, 1, 0) { Issue.check_weekly_sources! }
    assert Issue.weekly.exists?(period_key: "2026-W36")
    assert_not Issue.weekly.exists?(period_key: "2026-W37")
  end

  test "published_at 缺失时按检查当天所在周归属" do
    travel_to Time.utc(2026, 9, 10, 4, 0) do
      Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
      Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).with(367).returns(entries(6, published: nil))
      Issue.check_weekly_sources!
      assert Issue.weekly.exists?(period_key: "2026-W37")
    end
  end

  test "已入库的期号不重复写" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).never
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })

    Issue.check_weekly_sources!

    assert_equal issues(:weekly_w36), FetchRun.where(source: sources(:ruanyf)).last.issue
  end

  test "同一周两期各自成节、按期号排序" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).with(366).returns(entries(6, published: Time.utc(2026, 9, 8), meta: { issue_no: 366, issue_title: "上期" }))
    Issue.check_weekly_sources!

    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).with(367).returns(entries(6, published: Time.utc(2026, 9, 11), meta: { issue_no: 367, issue_title: "本期" }, offset: 100))
    Issue.check_weekly_sources!

    issue = Issue.weekly.find_by!(period_key: "2026-W37")
    assert_equal 12, issue.items.count
    assert_equal [ 366, 367 ], issue.weekly_sections.map { |s| s[:issue_no] }
  end

  test "AC-2.4 所有源无内容则不生成期" do
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })
    assert_no_difference("Issue.weekly.count") { Issue.check_weekly_sources! }
  end

  test "AC-2.3 RSS 周刊源写入本周节并记录抓取" do
    source = rss_weekly_source
    Adapters::Rss.any_instance.stubs(:fetch).returns(entries(2, section: nil, published: Time.current, meta: {}))
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })

    Issue.check_weekly_sources!

    issue = Issue.weekly.find_by!(period_key: PeriodKey.this_week)
    assert_equal 2, issue.items.where(source: source).count
    assert issue.published?
    assert_equal "succeeded", FetchRun.where(source: source).last.status
  end

  test "一源失败不阻塞其他源" do
    source = rss_weekly_source(sort_order: 0)   # sort_order 0 < 阮一峰的 1，.ordered.each 保证它先跑：先失败的源不该拖累后面的源
    Adapters::Rss.any_instance.stubs(:fetch).raises(Adapters::Rss::ParseError, "not a feed")
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
    Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).returns(entries(6, published: Time.utc(2026, 9, 11)))

    Issue.check_weekly_sources!

    assert_equal 6, Issue.weekly.find_by!(period_key: "2026-W37").items.count
    run = FetchRun.where(source: source).last
    assert_equal "failed", run.status
    assert_equal "not a feed", run.error_summary
  end

  test "按排序值依次处理周刊源" do
    source = rss_weekly_source(sort_order: 0)
    Adapters::Rss.any_instance.stubs(:fetch).returns([])
    Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
    issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })

    Issue.check_weekly_sources!

    # 只看这两个周刊源自己的记录：fetch_runs 的 hn_ok fixture 也是 scheduled，但跟周刊排序无关
    runs = FetchRun.order(:created_at).where(trigger: "scheduled", source: [ source, sources(:ruanyf) ])
    assert_equal source.id, runs.map(&:source_id).first
  end

  # AGENTS 不变量：job 幂等。一天里跑两次检查，阮一峰不重抓，RSS 节整节替换后条目数不变
  test "同一天重复检查不重复写入" do
    travel_to Time.utc(2026, 9, 10, 4, 0) do
      source = rss_weekly_source
      Adapters::Rss.any_instance.stubs(:fetch).returns(entries(2, section: nil, published: Time.current, meta: {}))
      Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
      Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).returns(entries(6, published: Time.utc(2026, 9, 11)))
      Issue.check_weekly_sources!
      issue = Issue.weekly.find_by!(period_key: "2026-W37")
      ruanyf_ids = issue.items.where(source: sources(:ruanyf)).order(:rank).pluck(:id)

      Adapters::RuanyfWeekly.any_instance.expects(:fetch_issue).never
      assert_no_difference("Item.count") { Issue.check_weekly_sources! }

      assert_equal ruanyf_ids, issue.items.where(source: sources(:ruanyf)).order(:rank).pluck(:id)
      assert_equal 2, issue.items.where(source: source).count
    end
  end

  test "weekly_sections 按源排序、按板块分组" do
    source = rss_weekly_source
    issue = issues(:weekly_w36)
    issue.replace_section!(sources(:ruanyf), [
      Adapters::Entry.new(title: "t1", url: "https://x/1", section: "科技动态", rank: 1, meta: { issue_no: 366, issue_title: "主题" }),
      Adapters::Entry.new(title: "t2", url: "https://x/2", section: "科技动态", rank: 2, meta: { issue_no: 366, issue_title: "主题" }),
      Adapters::Entry.new(title: "t3", url: "https://x/3", section: "工具", rank: 3, meta: { issue_no: 366, issue_title: "主题" })
    ], issue_no: 366)
    issue.replace_section!(sources(:ruanyf), [
      Adapters::Entry.new(title: "科技爱好者周刊（第 368 期）：坏了", url: "https://github.com/ruanyf/weekly/blob/master/docs/issue-368.md", rank: 1,
        meta: { issue_no: 368, issue_title: "坏了", degraded: true })
    ], issue_no: 368)
    issue.replace_section!(source, [ Adapters::Entry.new(title: "w", url: "https://w/1", rank: 1, meta: {}) ])

    sections = issue.weekly_sections

    assert_equal [ sources(:ruanyf), sources(:ruanyf), source ], sections.map { |s| s[:source] }
    assert_equal [ 366, 368, nil ], sections.map { |s| s[:issue_no] }
    assert_equal "主题", sections.first[:issue_title]
    assert_not sections.first[:degraded]
    assert sections.second[:degraded]
    assert_nil sections.last[:issue_title]
    assert_not sections.last[:degraded]
    assert_equal [ "科技动态", "工具" ], sections.first[:sections].map(&:first)
    assert_equal %w[ t1 t2 ], sections.first[:sections].first.last.map(&:title)
    assert_nil sections.last[:sections].sole.first
  end
end
