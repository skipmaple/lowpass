require "test_helper"

class Issue::PresentingTest < ActiveSupport::TestCase
  # 上海 9月9日 05:00（还没到 06:00 的生成时间）与 07:00（过了）
  BEFORE_DAILY_TIME = Time.utc(2026, 9, 8, 21, 0)
  AFTER_DAILY_TIME = Time.utc(2026, 9, 8, 23, 0)

  def publish!(period_key)
    Issue.create!(kind: "daily", period_key: period_key, state: "published",
                  generation_started_at: Time.utc(2026, 9, 8, 22, 0), published_at: Time.utc(2026, 9, 8, 22, 12))
  end

  # 5.1 边界：00:00 到 06:00 访问首页看到的是昨日那一期，期头要说清楚今天几点出
  test "生成时间之前且今天还没有期时，昨日那一期是 is_yesterday" do
    props = Issue.daily_props_for("2026-09-08", now: BEFORE_DAILY_TIME)

    assert props[:is_yesterday]
    assert_equal "昨日日刊，今日将于 06:00 生成", props[:status]
  end

  test "过了生成时间就不再是昨日那一期" do
    props = Issue.daily_props_for("2026-09-08", now: AFTER_DAILY_TIME)

    assert_not props[:is_yesterday]
    assert_nil props[:status]
  end

  test "今天已经出了期，昨日那一期就不再标 is_yesterday" do
    publish!("2026-09-09")

    props = Issue.daily_props_for("2026-09-08", now: BEFORE_DAILY_TIME)

    assert_not props[:is_yesterday]
  end

  test "前一期与后一期取相邻的日刊周期键，最新一期没有后一期" do
    publish!("2026-09-09")

    older = Issue.daily_props_for("2026-09-08", now: AFTER_DAILY_TIME)
    newer = Issue.daily_props_for("2026-09-09", now: AFTER_DAILY_TIME)

    assert_nil older[:prev_key]
    assert_equal "2026-09-09", older[:next_key]
    assert_equal "2026-09-08", newer[:prev_key]
    assert_nil newer[:next_key]
  end

  # 控制器已经查过这一期就传进来；显式的 nil 是「确实没有这一期」，不再回库查一遍
  test "传进来的期优先于按周期键查库" do
    props = Issue.daily_props_for("2026-09-08", issue: nil, now: AFTER_DAILY_TIME)

    assert_nil props[:state]
    assert_equal "本期未生成", props[:status]
    assert_equal "9月8日", props[:date_label]
  end
end

# 归档与周刊页的 props。上海 2026-09-10 12:00：fixture 的日刊 2026-09-08 与周刊 2026-W36 都在过去，本周是 2026-W37。
class Issue::ArchivePresentingTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 9, 10, 4)

  def entry(title, section: nil, rank: 1, issue_no: nil, issue_title: nil, url: nil)
    Adapters::Entry.new(title: title, url: url || "https://r.example/#{rank}#{issue_no}", section: section, rank: rank,
                        meta: { issue_no: issue_no, issue_title: issue_title }.compact)
  end

  def rss_weekly_source
    Source.create!(name: "命令行周报", adapter: "rss", publication: "weekly", sort_order: 2,
                   config: { feed_url: "https://w.example/feed" })
  end

  # PRD 6.2：按月分组、每天一行、上线前的日期不显示
  test "日刊归档从最早一期列到今天为止" do
    props = Issue.daily_archive_props(now: NOW)

    assert_equal "2026 年 9 月", props[:month_label]
    assert_equal %w[ 2026-09-10 2026-09-09 2026-09-08 ], props[:days].map { |day| day[:period_key] }
    assert_equal %w[ missing missing published ], props[:days].map { |day| day[:state] }
    assert_nil props[:prev_month]
    assert_nil props[:next_month]
  end

  test "缺期行只有一句缺期，没有各源结果" do
    row = Issue.daily_archive_props(now: NOW)[:days].first

    assert_equal "缺期", row[:published_label]
    assert_nil row[:source_marks]
    assert_equal "9月10日", row[:date_label]
  end

  test "各源结果按排序值给出条数或失败" do
    row = Issue.daily_archive_props(now: NOW)[:days].last

    assert_equal "HN 1 · GH 失败 · HAD 失败", row[:source_marks]
    assert_equal "06:12 发布", row[:published_label]
  end

  test "延迟生成与修订写进同一行" do
    issues(:daily_0908).update!(generated_late: true, revised_at: Time.utc(2026, 9, 7, 22, 42))

    row = Issue.daily_archive_props(now: NOW)[:days].last

    assert_equal "延迟生成于 06:12 · 已于 06:42 修订", row[:published_label]
  end

  # 空刊那句「今日为空刊，管理员已收到通知」在归档的一行里太长：只留状态记号
  test "空刊只留记号，生成中给出刷新提示" do
    Issue.create!(kind: "daily", period_key: "2026-09-09", state: "empty",
                  generation_started_at: Time.utc(2026, 9, 8, 22), published_at: Time.utc(2026, 9, 8, 22, 20))
    Issue.create!(kind: "daily", period_key: "2026-09-10", state: "generating",
                  generation_started_at: Time.utc(2026, 9, 9, 22))

    rows = Issue.daily_archive_props(now: NOW)[:days].index_by { |day| day[:period_key] }

    assert_nil rows["2026-09-09"][:published_label]
    assert_equal "生成中，约 1 分钟后刷新", rows["2026-09-10"][:published_label]
  end

  test "翻月只在最早一期与当月之间" do
    props = Issue.daily_archive_props(month: Date.new(2026, 8, 1), now: NOW)

    assert_empty props[:days]
    assert_nil props[:prev_month]
    assert_equal "2026-09", props[:next_month][:key]
    assert_equal "9 月", props[:next_month][:label]
  end

  # PRD 6.2、R-2.7：按年分组，每周一行，没有期的周标「本周无内容」
  test "周刊归档按周倒序，无内容的周标本周无内容" do
    props = Issue.weekly_archive_props(now: NOW)

    assert_equal "2026 年", props[:year_label]
    assert_equal %w[ 2026-W37 2026-W36 ], props[:weeks].map { |week| week[:period_key] }
    assert_equal "本周无内容", props[:weeks].first[:summary]
    # 无内容的周与空刊视觉一致（描边方块），不再借用缺期的叉（R56）
    assert_equal "empty", props[:weeks].first[:state]
    assert_equal "第 36 周", props[:weeks].last[:week_label]
    assert_equal "8月31日 至 9月6日", props[:weeks].last[:range_label]
  end

  test "摘要给阮一峰写期号与主题，给 RSS 源只写源名" do
    issue = issues(:weekly_w36)
    issue.replace_section!(sources(:ruanyf), [ entry("慢下来的理由", section: "本周话题", issue_no: 366, issue_title: "慢下来的理由") ], issue_no: 366)
    issue.replace_section!(rss_weekly_source, [ entry("fzf 0.60 加了多列预览", rank: 2), entry("shell 启动速度", rank: 3) ])

    row = Issue.weekly_archive_props(now: NOW)[:weeks].last

    assert_equal "阮一峰科技爱好者周刊 第 366 期 · 慢下来的理由 / 命令行周报", row[:summary]
    assert_equal 3, row[:count]
  end

  # weekly_archive_props 原本每期都经 Issue#weekly_sections 单独查一遍（≈2 条查询/有内容的周），
  # 一年最多 53 周就是 N+1。批量改法要做到查询数不随「有内容的周数」增长，摘要字符串跟改之前
  # （上面那条测试、Issue#section_issue_label 的文案）逐字一样。
  test "归档批量算 summary 与 count，查询数固定不随有内容的周数增长" do
    issue_w34 = Issue.create!(kind: "weekly", period_key: "2026-W34", state: "published",
      published_at: Time.utc(2026, 8, 21, 1), generation_started_at: Time.utc(2026, 8, 21, 1))
    issue_w34.replace_section!(sources(:ruanyf), [
      entry("上一期的话题", section: "本周话题", issue_no: 365, issue_title: "上一期的主题")
    ], issue_no: 365)

    issue_w35 = Issue.create!(kind: "weekly", period_key: "2026-W35", state: "published",
      published_at: Time.utc(2026, 8, 28, 1), generation_started_at: Time.utc(2026, 8, 28, 1))
    source_w35 = Source.create!(name: "独立开发周刊", adapter: "rss", publication: "weekly", sort_order: 2, config: { feed_url: "https://w35.example/feed" })
    issue_w35.replace_section!(source_w35, [ entry("独立开发者周记", rank: 1), entry("命令行技巧", rank: 2) ])

    issue_w36 = issues(:weekly_w36)
    issue_w36.replace_section!(sources(:ruanyf), [ entry("慢下来的理由", section: "本周话题", issue_no: 366, issue_title: "慢下来的理由") ], issue_no: 366)
    source_w36 = Source.create!(name: "命令行周报", adapter: "rss", publication: "weekly", sort_order: 2, config: { feed_url: "https://w36.example/feed" })
    issue_w36.replace_section!(source_w36, [ entry("fzf 0.60 加了多列预览", rank: 2), entry("shell 启动速度", rank: 3) ])

    props = nil
    # earliest 期键、按年选中的期、Item 的 counts 与 pluck、Source 各一条查询：5 条，跟一年
    # 53 周里几周真有内容无关（PeriodKey.weeks_in/week_range 都是纯 Ruby 日期计算，不查库）
    assert_queries_count(5) { props = Issue.weekly_archive_props(year: 2026, now: NOW) }

    weeks = props[:weeks].index_by { |week| week[:period_key] }
    assert_equal "阮一峰科技爱好者周刊 第 365 期 · 上一期的主题", weeks["2026-W34"][:summary]
    assert_equal 1, weeks["2026-W34"][:count]
    assert_equal "独立开发周刊", weeks["2026-W35"][:summary]
    assert_equal 2, weeks["2026-W35"][:count]
    assert_equal "阮一峰科技爱好者周刊 第 366 期 · 慢下来的理由 / 命令行周报", weeks["2026-W36"][:summary]
    assert_equal 3, weeks["2026-W36"][:count]
    assert_equal "本周无内容", weeks["2026-W37"][:summary]
    assert_nil weeks["2026-W37"][:count]
  end

  test "一期周刊都没有时只列本周" do
    Issue.weekly.destroy_all

    props = Issue.weekly_archive_props(now: NOW)

    assert_equal [ "2026-W37" ], props[:weeks].map { |week| week[:period_key] }
    assert_nil props[:prev_year]
    assert_nil props[:next_year]
  end

  test "越界的年份没有 props" do
    assert_nil Issue.weekly_archive_props(year: 2025, now: NOW)
    assert_nil Issue.weekly_archive_props(year: 2027, now: NOW)
  end

  # R51：周刊页每节自带原文地址、板块锚点与和日刊同一套的条目字段
  test "周刊节带原文地址与板块锚点" do
    issue = issues(:weekly_w36)
    issue.replace_section!(sources(:ruanyf), [
      entry("慢下来的理由", section: "本周话题", rank: 1, issue_no: 366, issue_title: "慢下来的理由"),
      entry("一个终端下的日志工具", section: "工具", rank: 2, issue_no: 366, issue_title: "慢下来的理由")
    ], issue_no: 366)
    issue.replace_section!(rss_weekly_source, [ entry("fzf 0.60 加了多列预览", rank: 3) ])

    props = Issue.weekly_props_for("2026-W36")
    ruanyf, rss = props[:sections]

    assert_equal "https://github.com/ruanyf/weekly/blob/master/docs/issue-366.md", ruanyf[:original_url]
    assert_equal "第 366 期 · 慢下来的理由", ruanyf[:issue_label]
    assert_equal [ "本周话题", "工具" ], ruanyf[:groups].map { |group| group[:name] }
    assert_equal 2, ruanyf[:groups].map { |group| group[:anchor] }.uniq.size
    assert_equal "https://w.example/", rss[:original_url]
    assert_nil rss[:issue_label]
    assert_nil rss[:groups].sole[:name]
  end

  test "周刊条目与日刊用同一套字段" do
    issues(:weekly_w36).replace_section!(sources(:ruanyf), [ entry("慢下来的理由", section: "本周话题", issue_no: 366) ], issue_no: 366)

    weekly = Issue.weekly_props_for("2026-W36")[:sections].sole[:groups].sole[:items].sole
    daily = issues(:daily_0908).items_by_source.values.flatten.first

    assert_equal daily.keys, weekly.keys
  end

  test "没有期的周仍然给出周次与附录 B 的一句" do
    props = Issue.weekly_props_for("2026-W01")

    assert_equal "第 1 周", props[:issue][:week_label]
    assert_equal "本周无内容", props[:issue][:status]
    assert_nil props[:issue][:state]
    assert_empty props[:sections]
  end
end
