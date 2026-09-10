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

  # AGENTS 不变量：job 幂等。一天里跑两次检查，阮一峰不重抓，RSS 节一条都不多写、id 也不换
  test "同一天重复检查不重复写入" do
    travel_to Time.utc(2026, 9, 10, 4, 0) do
      source = rss_weekly_source
      Adapters::Rss.any_instance.stubs(:fetch).returns(entries(2, section: nil, published: Time.current, meta: {}))
      Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(367)
      Adapters::RuanyfWeekly.any_instance.stubs(:fetch_issue).returns(entries(6, published: Time.utc(2026, 9, 11)))
      Issue.check_weekly_sources!
      issue = Issue.weekly.find_by!(period_key: "2026-W37")
      ruanyf_ids = issue.items.where(source: sources(:ruanyf)).order(:rank).pluck(:id)
      rss_rows = issue.items.where(source: source).order(:rank).pluck(:id, :rank)

      Adapters::RuanyfWeekly.any_instance.expects(:fetch_issue).never
      assert_no_difference("Item.count") { Issue.check_weekly_sources! }

      assert_equal ruanyf_ids, issue.items.where(source: sources(:ruanyf)).order(:rank).pluck(:id)
      assert_equal rss_rows, issue.items.where(source: source).order(:rank).pluck(:id, :rank)
    end
  end

  # R-2.8 已发布的节不重写：RSS 周刊源每天检查一次，新 entry 接在后面，周初那两条留在原位
  test "RSS 周刊节只追加新条目" do
    travel_to Time.utc(2026, 9, 10, 4, 0) do
      source = rss_weekly_source
      Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
      issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })
      Adapters::Rss.any_instance.stubs(:fetch).returns(entries(2, section: nil, published: Time.current, meta: {}))
      Issue.check_weekly_sources!

      issue = Issue.weekly.find_by!(period_key: "2026-W37")
      first_two = issue.items.where(source: source).order(:rank).pluck(:id, :rank)
      assert_equal [ 1, 2 ], first_two.map(&:last)

      Adapters::Rss.any_instance.stubs(:fetch).returns(entries(3, section: nil, published: Time.current, meta: {}))
      assert_difference("Item.count", 1) { Issue.check_weekly_sources! }

      rows = issue.items.where(source: source).order(:rank).pluck(:id, :rank, :title)
      assert_equal first_two, rows.first(2).map { |id, rank, _| [ id, rank ] }
      assert_equal [ 3, "t3" ], rows.last.last(2)
    end
  end

  # 周刊路径要跟日刊路径（Source::Fetching#fetch_now）对齐：同源重复地址在写入时被去掉，也要
  # 计进 FetchRun 的 dropped_count，不然 item_count 报的是抓到几条，不是这一节真的写进去几条。
  # 两条 entry 共用同一个 url_hash：write_rows 按 url_hash 去重，一条落地、一条算 dropped
  # （item_count 1、dropped_count 1）。同一天原样重抓一次：append_section! 发现两条的地址都
  # 已经入库（第一次落地那条 + 第二次这条重复的也指向同一地址），一条都不会新写，全算 dropped
  # （item_count 0、dropped_count 2）。
  test "RSS 周刊节内重复地址与重复检查都计入去重丢弃数" do
    travel_to Time.utc(2026, 9, 10, 4, 0) do
      source = rss_weekly_source
      dup_entries = [
        Adapters::Entry.new(title: "t1", url: "https://x/1", rank: 1, meta: {}),
        Adapters::Entry.new(title: "t1 重复", url: "https://x/1", rank: 2, meta: {})
      ]
      Adapters::Rss.any_instance.stubs(:fetch).returns(dup_entries)
      Adapters::RuanyfWeekly.any_instance.stubs(:latest_issue_number).returns(366)
      issues(:weekly_w36).items.create!(source: sources(:ruanyf), title: "x", url: "https://x/1", url_hash: "0" * 64, fetched_at: Time.current, meta: { issue_no: 366 })

      Issue.check_weekly_sources!

      # travel_to 冻结了时间，两次检查的 FetchRun#created_at 完全相同，order(:created_at) 分不出
      # 先后：用「除了第一条 run 之外那条」定位第二次检查留下的记录，不靠 created_at 排前后。
      first_run = FetchRun.where(source: source).sole
      assert_equal 1, first_run.item_count
      assert_equal 1, first_run.dropped_count
      assert_equal 1, Issue.weekly.find_by!(period_key: "2026-W37").items.where(source: source).count

      Issue.check_weekly_sources!

      second_run = FetchRun.where(source: source).where.not(id: first_run.id).sole
      assert_equal 0, second_run.item_count
      assert_equal 2, second_run.dropped_count
      assert_equal 1, Issue.weekly.find_by!(period_key: "2026-W37").items.where(source: source).count
    end
  end

  # source_states 是 merge 出来的：write_section! 不加锁的话，两个各自 Issue.find 出来的实例
  # （对应两个不同源各自的抓取进程）先后 merge 时，后写的会拿着自己读进来的旧值覆盖掉先写的那份，
  # 先写的那个源的状态就丢了。with_lock 在 merge 前重新读一次锁住的行，两次写都能留下来。
  test "两个源先后 write_section! 各自的 source_states 都保留" do
    # fixture 已经带 ruanyf => "ok"，两个新源都不在这份 source_states 里，才能验证锁：
    # 任何一次 merge 用了过期的读，另一次的写就会被盖掉
    issue = issues(:weekly_w36)
    source_a = Source.create!(name: "周刊源 A", adapter: "rss", publication: "weekly", sort_order: 2, config: { feed_url: "https://a.example/feed" })
    source_b = Source.create!(name: "周刊源 B", adapter: "rss", publication: "weekly", sort_order: 3, config: { feed_url: "https://b.example/feed" })
    first = Issue.find(issue.id)
    second = Issue.find(issue.id)

    first.write_section!(source_a, [ Adapters::Entry.new(title: "t1", url: "https://x/1", rank: 1, meta: {}) ])
    second.write_section!(source_b, [ Adapters::Entry.new(title: "t2", url: "https://x/2", rank: 1, meta: {}) ])

    assert_equal({ sources(:ruanyf).id => "ok", source_a.id => "ok", source_b.id => "ok" }, issue.reload.source_states)
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
