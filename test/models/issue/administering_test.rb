require "test_helper"

# 后台期列表（5.6）：一个月的日刊逐天列（缺期也占一行）、周一落在该月的周刊
class Issue::AdministeringTest < ActiveSupport::TestCase
  test "当月的日刊与周刊、汇总行" do
    result = Issue.admin_rows(kind: "all", month: nil, now: Time.utc(2026, 9, 9, 4))   # 上海 9月9日 12:00

    assert_equal "2026 年 9 月", result[:month_label]
    assert_equal "2026-09", result[:month]
    daily = result[:rows].select { |row| row[:kind] == "daily" }
    assert_equal %w[ 2026-09-09 2026-09-08 ], daily.map { |row| row[:period_key] }
    today = daily.first
    assert_equal "missing", today[:state]
    assert_equal "缺期", today[:state_label]
    assert_equal [], today[:refetchable_sources]
    published = daily.last
    assert_equal "published", published[:state]
    assert_equal "已发布", published[:state_label]
    assert_equal "发布 06:12", published[:time_label]
    assert_equal "HN 1 · GH 失败 · HAD 失败", published[:source_marks]
    assert_equal [ "Hacker News", "GitHub Trending", "Hackaday" ], published[:refetchable_sources].map { |s| s[:name] }
    weekly = result[:rows].select { |row| row[:kind] == "weekly" }
    assert_equal [ "2026-W36" ], weekly.map { |row| row[:period_key] }
    assert_equal "发布 2026-09-04 09:03", weekly.first[:time_label]
    assert_equal "9 月 · 2 期 · 0 空刊 · 1 缺期", result[:summary]
  end

  test "只看日刊或周刊" do
    now = Time.utc(2026, 9, 9, 4)
    assert Issue.admin_rows(kind: "daily", month: nil, now: now)[:rows].all? { |row| row[:kind] == "daily" }
    assert Issue.admin_rows(kind: "weekly", month: nil, now: now)[:rows].all? { |row| row[:kind] == "weekly" }
  end

  test "延迟与修订进状态词" do
    issues(:daily_0908).update!(generated_late: true, revised_at: Time.utc(2026, 9, 7, 22, 42))

    row = Issue.admin_rows(kind: "daily", month: nil, now: Time.utc(2026, 9, 9, 4))[:rows].find { |r| r[:period_key] == "2026-09-08" }

    assert_equal "已发布 · 延迟 · 已修订", row[:state_label]
    assert_equal "发布 06:12 · 修订 06:42", row[:time_label]
  end

  test "跨日修订标明发布与修订的上海日期" do
    issues(:daily_0908).update!(revised_at: Time.utc(2026, 9, 8, 22, 42))

    Time.use_zone("America/Los_Angeles") do
      row = Issue.admin_rows(kind: "daily", month: "2026-09", now: Time.utc(2026, 9, 9, 4))[:rows].find { |entry| entry[:period_key] == "2026-09-08" }
      assert_equal "发布 2026-09-08 06:12 · 修订 2026-09-09 06:42", row[:time_label]
    end
  end

  test "周刊修订也保留发布与修订日期" do
    issue = issues(:weekly_w36)
    issue.update!(revised_at: Time.utc(2026, 9, 5, 1, 3))

    row = Issue.admin_rows(kind: "weekly", month: "2026-09", now: Time.utc(2026, 9, 9, 4))[:rows].find { |entry| entry[:period_key] == issue.period_key }
    assert_equal "发布 2026-09-04 09:03 · 修订 2026-09-05 09:03", row[:time_label]
  end

  test "日刊真实计数与供应商及画像准备状态分开" do
    row = -> { Issue.admin_rows(kind: "daily", month: "2026-09", now: Time.find_zone("Asia/Shanghai").parse("2026-09-10 12:00"))[:rows].find { |r| r[:period_key] == "2026-09-08" } }
    assert_equal({ with_reason: 0, abstained: 0, retained: 0, missing: 1, ready: false, unready_label: "未配置模型供应商", last_assessed_label: nil }, row.call[:reasons])
    with_model_provider do
      InterestArea.update_all(enabled: false)
      assert_equal({ with_reason: 0, abstained: 0, retained: 0, missing: 1, ready: false, unready_label: "兴趣画像为空", last_assessed_label: nil }, row.call[:reasons])
      InterestArea.update_all(enabled: true)

      assert_equal({ with_reason: 0, abstained: 0, retained: 0, missing: 1, ready: true, unready_label: nil, last_assessed_label: nil }, row.call[:reasons])
      items(:hn_one).update!(reason: "有了", interest_tag: "AI / LLM")
      assert_equal({ with_reason: 1, abstained: 0, retained: 0, missing: 0, ready: true, unready_label: nil, last_assessed_label: nil }, row.call[:reasons])
    end
  end

  # 月份只在「最早一期所在月 到 本月」之间有页（与日刊归档一致），越界返回 nil 让控制器 404
  test "翻月与越界" do
    now = Time.utc(2026, 9, 9, 4)
    assert_nil Issue.admin_rows(kind: "all", month: "2026-08", now: now)
    assert_nil Issue.admin_rows(kind: "all", month: "2026-10", now: now)
    assert_nil Issue.admin_rows(kind: "all", month: "2026-13", now: now)

    Issue.daily.create!(period_key: "2026-08-30", state: "published", published_at: Time.utc(2026, 8, 29, 22, 12), generation_started_at: Time.utc(2026, 8, 29, 22))
    august = Issue.admin_rows(kind: "all", month: "2026-08", now: now)
    assert_equal "2026 年 8 月", august[:month_label]
    assert_equal "2026-08", august[:month]
    assert_nil august[:prev_month]
    assert_equal "9 月", august[:next_month][:label]
    assert_equal %w[ 2026-08-31 2026-08-30 ], august[:rows].select { |r| r[:kind] == "daily" }.map { |r| r[:period_key] }
    assert_equal "8 月", Issue.admin_rows(kind: "all", month: nil, now: now)[:prev_month][:label]
  end

  test "四类可见日刊计数互斥且最后判断独立转为上海时间" do
    issue = issues(:daily_0908)
    stamp = Time.utc(2026, 9, 8, 16, 30)
    [ [ "written", "旧理由", nil, false ], [ "abstained", nil, stamp, false ], [ "retained", "保留内容", stamp - 1.hour, false ], [ "hidden", nil, stamp + 1.hour, true ] ].each do |key, reason, assessed_at, hidden|
      item = items(:hn_one).dup
      item.assign_attributes(url: "https://example.test/#{key}", url_hash: Digest::SHA256.hexdigest(key), reason: reason, hidden: hidden)
      item.save!
      item.record_reason_abstention(assessed_at: assessed_at) if assessed_at
    end
    counts = Item.reason_counts_by_issue([ issue.id, issues(:weekly_w36).id ])
    assert_equal [ 1, 1, 1, 1 ], counts.fetch(issue.id).values_at(:with_reason, :abstained, :retained, :missing)
    assert_equal 4, counts.fetch(issue.id).values_at(:with_reason, :abstained, :retained, :missing).sum
    assert_equal stamp, counts.fetch(issue.id).fetch(:last_assessed_at)
    assert_equal [ 0, 0, 0, 0, nil ], counts.fetch(issues(:weekly_w36).id).values_at(:with_reason, :abstained, :retained, :missing, :last_assessed_at)
    row = Issue.admin_rows(kind: "daily", month: "2026-09", now: Time.utc(2026, 9, 10))[:rows].find { |entry| entry[:period_key] == issue.period_key }
    assert_equal "最后处理 2026-09-09 00:30", row[:reasons][:last_assessed_label]
    assert_equal [ 1, 1, 1, 1 ], row[:reasons].values_at(:with_reason, :abstained, :retained, :missing)
    assert_equal "未配置模型供应商", row[:reasons][:unready_label]
  end

  test "一月多期批量统计不逐行加载条目" do
    (1..30).each do |day|
      next if day == 8
      Issue.create!(kind: "daily", period_key: format("2026-09-%02d", day), state: "published", published_at: Time.current, generation_started_at: Time.current)
    end
    statements = []
    listener = ->(*args) do
      payload = args.last
      statements << payload[:sql] if payload[:sql].match?(/FROM "items"/)
    end
    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
      Item.reason_counts_by_issue(Issue.daily.pluck(:id))
    end
    assert_operator statements.length, :<=, 3
    assert statements.all? { |sql| sql.include?("GROUP BY") }, statements.inspect
  end
end
