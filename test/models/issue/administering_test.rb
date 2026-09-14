require "test_helper"

# 后台期列表（5.6）：一个月的日刊逐天列（缺期也占一行）、周一落在该月的周刊
class Issue::AdministeringTest < ActiveSupport::TestCase
  test "当月的日刊与周刊、汇总行" do
    result = Issue.admin_rows(kind: "all", month: nil, now: Time.utc(2026, 9, 9, 4))   # 上海 9月9日 12:00

    assert_equal "2026 年 9 月", result[:month_label]
    daily = result[:rows].select { |row| row[:kind] == "daily" }
    assert_equal %w[ 2026-09-09 2026-09-08 ], daily.map { |row| row[:period_key] }
    today = daily.first
    assert_equal "missing", today[:state]
    assert_equal "缺期", today[:state_label]
    assert_equal [], today[:refetchable_sources]
    published = daily.last
    assert_equal "published", published[:state]
    assert_equal "已发布", published[:state_label]
    assert_equal "06:12", published[:time_label]
    assert_equal "HN 1 · GH 失败 · HAD 失败", published[:source_marks]
    assert_equal [ "Hacker News", "GitHub Trending", "Hackaday" ], published[:refetchable_sources].map { |s| s[:name] }
    weekly = result[:rows].select { |row| row[:kind] == "weekly" }
    assert_equal [ "2026-W36" ], weekly.map { |row| row[:period_key] }
    assert_equal "9月4日 09:03", weekly.first[:time_label]
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
    assert_equal "06:12 / 06:42", row[:time_label]
  end

  test "日刊行带理由状态：未配置 / 兴趣画像为空 / 缺 N 条 / 已生成" do
    row = -> { Issue.admin_rows(kind: "daily", month: "2026-09", now: Time.find_zone("Asia/Shanghai").parse("2026-09-10 12:00"))[:rows].find { |r| r[:period_key] == "2026-09-08" } }
    assert_equal({ label: "未配置模型供应商", missing: 1, ready: false }, row.call[:reasons])
    with_model_provider do
      InterestArea.update_all(enabled: false)
      assert_equal({ label: "兴趣画像为空", missing: 1, ready: false }, row.call[:reasons])
      InterestArea.update_all(enabled: true)

      assert_equal({ label: "缺 1 条", missing: 1, ready: true }, row.call[:reasons])
      items(:hn_one).update!(reason: "有了", interest_tag: "AI / LLM")
      assert_equal({ label: "已生成", missing: 0, ready: true }, row.call[:reasons])
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
    assert_nil august[:prev_month]
    assert_equal "9 月", august[:next_month][:label]
    assert_equal %w[ 2026-08-31 2026-08-30 ], august[:rows].select { |r| r[:kind] == "daily" }.map { |r| r[:period_key] }
    assert_equal "8 月", Issue.admin_rows(kind: "all", month: nil, now: now)[:prev_month][:label]
  end
end
