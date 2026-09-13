require "test_helper"

# R-4.8 索引跟着条目走：单条建、改在事务提交后同步到 Search::Record；删除由外键级联（record_test 已验）
class SearchableTest < ActiveSupport::TestCase
  def create_item(title, **attrs)
    url = "https://h.example/#{SecureRandom.hex(4)}"
    issues(:daily_0908).items.create!({ source: sources(:hn), title: title, url: url, url_hash: UrlNormalizer.url_hash(url), fetched_at: Time.current, rank: 2 }.merge(attrs))
  end

  test "新建条目提交后进索引" do
    item = create_item("Kubernetes operator in Rust")

    assert_equal "Kubernetes operator in Rust", Search::Record.find_by!(item_id: item.id).title
  end

  test "改标题后索引副本更新" do
    item = create_item("Before")
    item.update!(title: "After")

    assert_equal "After", Search::Record.find_by!(item_id: item.id).title
  end

  test "下架后索引行删除，恢复后再建" do
    item = create_item("Visible")
    item.update!(hidden: true)
    assert_not Search::Record.exists?(item_id: item.id)

    item.update!(hidden: false)
    assert Search::Record.exists?(item_id: item.id)
  end
end
