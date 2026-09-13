require "test_helper"

# 装订走 insert_all!，不经过 Item 的回调：整栏写入后必须批量进索引（R-4.8「发布或修订后 1 分钟内可搜」）
class Issue::SectionsTest < ActiveSupport::TestCase
  def entry(title, rank) = Adapters::Entry.new(title: title, url: "https://h.example/#{rank}", rank: rank)

  test "replace_section! 把新条目整栏写进索引，旧条目的索引行随之消失" do
    issue = issues(:daily_0908)
    Search::Record.rebuild!
    old_id = items(:hn_one).id

    issue.replace_section!(sources(:hn), [ entry("Kubernetes operator in Rust", 1), entry("Second", 2) ])

    assert_not Search::Record.exists?(item_id: old_id)
    assert_equal [ "Kubernetes operator in Rust", "Second" ], Search::Record.where(source_id: sources(:hn).id).order(:title).pluck(:title)
    assert_equal issue.items.where(source: sources(:hn)).pluck(:id).sort, Search::Record.where(source_id: sources(:hn).id).pluck(:item_id).sort
  end

  test "append_section! 只给新地址建索引行" do
    issue = issues(:weekly_w36)
    issue.append_section!(sources(:ruanyf), [ entry("First", 1) ])
    issue.append_section!(sources(:ruanyf), [ entry("First", 1), entry("Second", 2) ])

    assert_equal %w[ First Second ], Search::Record.where(issue_id: issue.id).order(:title).pluck(:title)
    assert_equal 2, issue.items.count
  end
end
