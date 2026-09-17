require "test_helper"

# 打分、排序、分页（设计 5.2 到 5.4）。阈值用真实 pg_trgm 核过：kuber↔Kubernetes 0.83、
# operatr↔operator 0.75、kubernets↔Kubernetes 0.80、rustlang↔Rust 0.44。
class Search::RunnerTest < ActiveSupport::TestCase
  test "AC-4.1 kuber rust 命中 Kubernetes operator in Rust" do
    index_item("Kubernetes operator in Rust")
    index_item("A soldering iron teardown")

    assert_equal [ "Kubernetes operator in Rust" ], found_titles(search("kuber rust"))
  end

  test "AC-4.2 终端工具 与 终端 日志 都命中 一个终端下的日志工具" do
    index_item("一个终端下的日志工具")

    assert_equal [ "一个终端下的日志工具" ], found_titles(search("终端工具"))
    assert_equal [ "一个终端下的日志工具" ], found_titles(search("终端 日志"))
  end

  test "拼写容错：5 到 8 字符允许约 1 个错，9 字符起约 2 个错" do
    index_item("Kubernetes operator in Rust")

    assert_equal 1, search("operatr").total
    assert_equal 1, search("kubernets").total
    assert_equal 0, search("rustlang").total
  end

  test "2 到 4 字符的拉丁词只按词首前缀命中" do
    index_item("Kubernetes operator in Rust")

    assert_equal 1, search("ru").total
    assert_equal 0, search("ube").total
  end

  test "C C++ C# 按独立技术词匹配，不混入前缀或彼此" do
    index_item("C language")
    index_item("用C++写的工具")
    index_item("C# compiler")
    index_item("CSS and Crystal")
    index_item("Objective-C++17 and abc++ _C C+++ C##")

    assert_equal [ "C language" ], found_titles(search("C"))
    assert_equal [ "用C++写的工具" ], found_titles(search("C++"))
    assert_equal [ "C# compiler" ], found_titles(search("C#"))
  end

  test "带符号的查询参数仍作为数据处理" do
    index_item("C++ handbook")
    index_item("Unrelated handbook")

    assert_equal [ "C++ handbook" ], found_titles(search("C++'"))
    assert_equal 0, search("' OR 1=1 --").total
  end

  test "中文子串不区分位置；通配符在解析时就当标点去掉，剩下的字照常命中" do
    index_item("一个终端下的日志工具")

    assert_equal 1, search("日志").total
    assert_equal 1, search("日%").total
    assert_equal 0, search("志日").total
  end

  test "R-4.3 权重：全命中排在部分命中之前，标题命中排在摘要命中之前" do
    index_item("About logs", summary: "the terminal")
    index_item("Terminal")
    index_item("Terminal viewer")

    assert_equal [ "Terminal viewer", "Terminal", "About logs" ], found_titles(search("terminal viewer"))
  end

  test "同分按发布日期倒序；sort=date 先按日期" do
    index_item("Rust")
    index_item("Rust weekly", issue: issues(:weekly_w36), source: sources(:ruanyf), published_at: Time.utc(2026, 9, 10, 4))
    index_item("Notes", issue: issues(:weekly_w36), source: sources(:ruanyf), summary: "rust", published_at: Time.utc(2026, 9, 11, 4))

    # 两条标题命中同分（4），发布日期新的在前；摘要命中（1）垫底
    assert_equal [ "Rust weekly", "Rust", "Notes" ], found_titles(search("rust"))
    assert_equal [ "Notes", "Rust weekly", "Rust" ], found_titles(search("rust", sort: "date"))
  end

  # 数据库按 ctype 把汉字当词字符：靠索引副本在中外文交界处补的空格，贴着中文的拉丁词才有词首可认
  test "贴着中文的拉丁词也按词首与拼写容错命中" do
    index_item("用Rust写的终端工具")
    index_item("使用Kubernetes做编排")

    assert_equal [ "用Rust写的终端工具" ], found_titles(search("rust"))
    assert_equal [ "使用Kubernetes做编排" ], found_titles(search("kuber"))
    assert_equal [ "用Rust写的终端工具" ], found_titles(search("终端工具"))
  end

  test "AC-4.3 筛选：刊物、日期范围含首尾、来源之间 OR、维度之间 AND" do
    daily = index_item("Rust in the daily")
    # UTC 9月3日 04:00 是上海 9月3日 12:00
    weekly = index_item("Rust in the weekly", issue: issues(:weekly_w36), source: sources(:ruanyf), published_at: Time.utc(2026, 9, 3, 4))

    assert_equal [ weekly.title ], found_titles(search("rust", type: "weekly"))
    assert_equal [ daily.title, weekly.title ], found_titles(search("rust", from: "2026-09-03", to: "2026-09-08"))
    assert_equal [ weekly.title ], found_titles(search("rust", from: "2026-09-03", to: "2026-09-03"))
    assert_equal [ daily.title ], found_titles(search("rust", from: "2026-09-04"))
    assert_equal [ daily.title ], found_titles(search("rust", source: sources(:hn).id))
    assert_equal [ daily.title, weekly.title ], found_titles(search("rust", source: "#{sources(:hn).id},#{sources(:ruanyf).id}"))
    assert_equal [], found_titles(search("rust", type: "daily", source: sources(:ruanyf).id))
  end

  test "只搜已发布的期" do
    generating = Issue.create!(kind: "daily", period_key: "2026-09-11", state: "generating", generation_started_at: Time.current)
    index_item("Rust while generating", issue: generating)

    assert_equal 0, search("rust").total

    generating.update!(state: "published", published_at: Time.current)
    assert_equal 1, search("rust").total
  end

  test "停用源的历史条目仍可搜，hidden 的条目不可搜" do
    sources(:hn).update!(enabled: false)
    index_item("Rust from a disabled source")
    index_item("Rust hidden", hidden: true)

    assert_equal [ "Rust from a disabled source" ], found_titles(search("rust"))
  end

  test "R-4.7 每页 20 条，名次连续，页数封顶 50" do
    25.times { |i| index_item("Rust item #{i}") }

    first = search("rust")
    assert_equal 20, first.entries.size
    assert_equal 25, first.total
    assert_equal 2, first.pages
    assert_equal (1..20).to_a, first.entries.map(&:rank)

    second = search("rust", page: "2")
    assert_equal 5, second.entries.size
    assert_equal (21..25).to_a, second.entries.map(&:rank)

    # 同分同日的 25 条靠 item_id 定序：两页不重叠、合起来正好是全部
    assert_equal 25, (found_titles(first) + found_titles(second)).uniq.size

    assert_equal 50, Search::Result.new(entries: [], total: 1001, page: 1, latency_ms: 0, status: "ok").pages
    assert_equal 0, Search::Result.new(entries: [], total: 0, page: 1, latency_ms: 0, status: "ok").pages
  end

  test "结果条目预加载了条目与源，带分数" do
    index_item("Kubernetes operator in Rust", summary: "Rust SDK")
    entry = search("rust").entries.sole

    assert_equal "Hacker News", entry.record.item.source.name
    assert_equal 5, entry.score
  end

  test "空查询不下库，直接给空结果" do
    result = search("，。")

    assert result.ok?
    assert_equal 0, result.total
    assert_equal [], result.entries
    assert_equal 0, result.pages
  end

  test "两条语句在事务里、带 500 ms 的 statement_timeout 与 0.45 的 word_similarity 下限" do
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |event| statements << event.payload[:sql] }
    search("kubernetes")

    assert_includes statements, "SET LOCAL statement_timeout = 500"
    assert_includes statements, "SET LOCAL pg_trgm.word_similarity_threshold = 0.45"
    assert(statements.any? { |sql| sql.include?("word_similarity('kubernetes'") })
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # 真的超时：SET LOCAL 排在事务外只是一句警告不是错误，这一条钉住它确实在事务里生效。
  # pg_sleep 每行睡 1 秒，1 行就够 50 ms 的 statement_timeout 打断
  test "statement_timeout 在事务里生效，超时归 timeout" do
    index_item("Rust")
    Search::Runner.any_instance.stubs(:matching).returns(Search::Record.published.where("pg_sleep(1) IS NOT NULL"))

    result = Search::Runner.call(Search::Query.parse(q: "rust"), timeout_ms: 50)

    assert_equal "timeout", result.status
  end

  test "超时归 timeout：上报错误，不抛出，结果为空" do
    Search::Runner.any_instance.stubs(:run).raises(ActiveRecord::QueryCanceled, "canceling statement due to statement timeout")
    Rails.error.expects(:report).once

    result = search("rust")

    assert_equal "timeout", result.status
    assert_not result.ok?
    assert_equal 0, result.total
    assert_equal [], result.entries
  end

  test "连接失败归 error" do
    Search::Runner.any_instance.stubs(:run).raises(PG::ConnectionBad, "server closed the connection unexpectedly")

    assert_equal "error", search("rust").status
  end

  test "其他异常照常抛出" do
    Search::Runner.any_instance.stubs(:run).raises(ActiveRecord::StatementInvalid, "syntax error")

    assert_raises(ActiveRecord::StatementInvalid) { search("rust") }
  end

  test "5.7 搜索连续三次不可用告警一次，恢复后发已恢复" do
    Rails.cache.clear
    # pg_sleep 是按行睡的（跟上面的超时用例一样）：search_records 一条都没有的话这个 WHERE
    # 根本不会对任何行求值，也就永远不会真的超时，所以这里先索引一条
    index_item("Rust")
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      Search::Runner.any_instance.stubs(:matching).returns(Search::Record.published.where("pg_sleep(1) IS NOT NULL"))
      assert_no_difference("AlertEvent.count") { 2.times { Search::Runner.call(Search::Query.parse({ q: "rust" }), timeout_ms: 50) } }
      assert_difference("AlertEvent.where(kind: 'search_unavailable').count", 1) { Search::Runner.call(Search::Query.parse({ q: "rust" }), timeout_ms: 50) }

      Search::Runner.any_instance.unstub(:matching)
      Search::Runner.call(Search::Query.parse({ q: "rust" }))
      assert_not_nil AlertEvent.find_by!(kind: "search_unavailable").recovered_at
    end
  end
end
