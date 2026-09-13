require "test_helper"

# 索引副本（设计 3.1、第 4 节）：一行一条可见条目，可搜列是 NFKC 归一化的副本，展示仍用 items 原文
class Search::RecordTest < ActiveSupport::TestCase
  def create_item(issue, source, title, url, **attrs)
    issue.items.create!({ source: source, title: title, url: url, url_hash: UrlNormalizer.url_hash(url), fetched_at: Time.current, rank: 1 }.merge(attrs))
  end

  test "index_items! 为可见条目建行，字段取自条目、期与源" do
    item = items(:hn_one)
    Search::Record.index_items!([ item.id ])

    record = Search::Record.find_by!(item_id: item.id)
    assert_equal "daily", record.publication
    assert_equal "2026-09-08", record.period_key
    assert_equal Date.new(2026, 9, 8), record.published_on
    assert_equal "Show HN: A terminal log viewer written in Rust", record.title
    assert_equal "Hacker News", record.source_name
    assert_equal sources(:hn).id, record.source_id
    assert_nil record.section
    assert_nil record.anchor
  end

  test "索引列是 NFKC 归一化后的副本，原文不动" do
    item = items(:hn_one)
    item.update_column(:title, "ＫＵＢＥＲＮＥＴＥＳ ｏｐｅｒａｔｏｒ")
    Search::Record.index_items!([ item.id ])

    assert_equal "KUBERNETES operator", Search::Record.find_by!(item_id: item.id).title
    assert_equal "ＫＵＢＥＲＮＥＴＥＳ ｏｐｅｒａｔｏｒ", item.reload.title
  end

  test "索引副本在中外文交界处补空格，拉丁词才能按词首匹配" do
    item = items(:hn_one)
    item.update_column(:title, "用Rust写的终端工具")
    Search::Record.index_items!([ item.id ])

    assert_equal "用 Rust 写的终端工具", Search::Record.find_by!(item_id: item.id).title
    assert_equal "用Rust写的终端工具", item.reload.title
  end

  test "再次索引是 upsert：一条一行，行 id 不变，内容更新" do
    item = items(:hn_one)
    Search::Record.index_items!([ item.id ])
    id = Search::Record.find_by!(item_id: item.id).id
    item.update_column(:title, "Renamed")
    Search::Record.index_items!([ item.id ])

    assert_equal 1, Search::Record.where(item_id: item.id).count
    assert_equal id, Search::Record.find_by!(item_id: item.id).id
    assert_equal "Renamed", Search::Record.find_by!(item_id: item.id).title
  end

  test "hidden 的条目删行，不存在的 id 跳过" do
    item = items(:hn_one)
    Search::Record.index_items!([ item.id ])
    item.update_column(:hidden, true)
    Search::Record.index_items!([ item.id, "nope" ])

    assert_not Search::Record.exists?(item_id: item.id)
  end

  test "条目删除时索引行随外键级联消失" do
    item = items(:hn_one)
    Search::Record.index_items!([ item.id ])
    item.delete

    assert_not Search::Record.exists?(item_id: item.id)
  end

  test "周刊条目：published_on 取发布时间的上海日期，没有则取周一；anchor 取稳定锚点" do
    issue = issues(:weekly_w36)
    # UTC 9月3日 16:30 是上海 9月4日 00:30
    dated = create_item(issue, sources(:ruanyf), "有日期", "https://r.example/1", rank: 1, section: "工具",
                        published_at: Time.utc(2026, 9, 3, 16, 30), meta: { "issue_no" => 366, "anchor" => "工具" })
    undated = create_item(issue, sources(:ruanyf), "无日期", "https://r.example/2", rank: 2)
    Search::Record.index_items!([ dated.id, undated.id ])

    assert_equal Date.new(2026, 9, 4), Search::Record.find_by!(item_id: dated.id).published_on
    assert_equal "issue-366-工具", Search::Record.find_by!(item_id: dated.id).anchor
    assert_equal Date.new(2026, 8, 31), Search::Record.find_by!(item_id: undated.id).published_on
    assert_equal "source-#{sources(:ruanyf).id}", Search::Record.find_by!(item_id: undated.id).anchor
  end

  test "rebuild! 清空重建，只含可见条目，返回行数" do
    hidden = create_item(issues(:daily_0908), sources(:hn), "hidden", "https://h.example/x", rank: 2, hidden: true)
    Search::Record.create!(item: hidden, issue: hidden.issue, source: hidden.source, publication: "daily", period_key: "2026-09-08",
                           published_on: Date.new(2026, 9, 8), title: "stale", source_name: "stale")

    assert_equal 1, Search::Record.rebuild!
    assert_equal [ items(:hn_one).id ], Search::Record.pluck(:item_id)
  end

  test "超长的锚点截到 120 字，不让整栏装订失败" do
    item = create_item(issues(:weekly_w36), sources(:ruanyf), "长板块", "https://r.example/9", rank: 9, meta: { "issue_no" => 366, "anchor" => "板" * 130 })
    Search::Record.index_items!([ item.id ])

    assert_equal 120, Search::Record.find_by!(item_id: item.id).anchor.length
  end

  test "所在期标签：日刊是日期，周刊是周次加板块，板块可空" do
    Search::Record.index_items!([ items(:hn_one).id ])
    assert_equal "9月8日", Search::Record.find_by!(item_id: items(:hn_one).id).where_label
    assert_equal "9月8日", Search::Record.find_by!(item_id: items(:hn_one).id).published_label

    issue = issues(:weekly_w36)
    with_section = create_item(issue, sources(:ruanyf), "a", "https://r.example/1", rank: 1, section: "工具", meta: { "issue_no" => 366, "anchor" => "工具" })
    without = create_item(issue, sources(:ruanyf), "b", "https://r.example/2", rank: 2)
    Search::Record.index_items!([ with_section.id, without.id ])

    assert_equal "第 36 周 · 工具", Search::Record.find_by!(item_id: with_section.id).where_label
    assert_equal "第 36 周", Search::Record.find_by!(item_id: without.id).where_label
    assert_equal "8月31日", Search::Record.find_by!(item_id: without.id).published_label
  end
end
