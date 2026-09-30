require "test_helper"

# 收藏（PRD 5.10）：一人一链接一条，带快照；重抓换掉条目行不影响它（AC-10.3）；取消后凭凭据原样恢复（R-10.7）
class FavoriteTest < ActiveSupport::TestCase
  setup do
    @user = users(:drew)
    @item = items(:hn_one)
  end

  def weekly_item
    index_item("Zed", issue: issues(:weekly_w36), source: sources(:ruanyf), section: "工具", meta: { "issue_no" => 366, "anchor" => "工具" })
  end

  test "keep 把条目抄成快照" do
    @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器", summary: "A fast viewer.")

    favorite = Favorite.keep(@user, @item)

    assert_equal @user, favorite.user
    assert_equal @item.url_hash, favorite.url_hash
    assert_equal "https://example.com/termlog", favorite.url
    assert_equal "Show HN: A terminal log viewer written in Rust", favorite.title
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", favorite.title_zh
    assert_equal "A fast viewer.", favorite.summary
    assert_equal sources(:hn), favorite.source
    assert_equal "daily", favorite.publication
    assert_equal "2026-09-08", favorite.period_key
    assert_nil favorite.anchor
    assert_equal "2026年9月8日", favorite.where_label
  end

  test "周刊条目的快照带板块名与板块锚点" do
    favorite = Favorite.keep(@user, weekly_item)

    assert_equal "weekly", favorite.publication
    assert_equal "2026-W36", favorite.period_key
    assert_equal "工具", favorite.section
    assert_equal "issue-366-工具", favorite.anchor
    assert_equal "2026年 · 第 36 周 · 工具", favorite.where_label
  end

  # R-10.2 收藏的是链接：同一链接再收藏（同一条，或它在另一期再出现）返回原来那条
  test "同一链接只有一条，所在期是第一次收藏的那一期" do
    first = Favorite.keep(@user, @item)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", generation_started_at: Time.current, published_at: Time.current)
    again = later.items.create!(source: sources(:hn), title: "Same link again", url: @item.url, url_hash: @item.url_hash, fetched_at: Time.current, rank: 1)

    assert_equal first, Favorite.keep(@user, @item)
    assert_equal first, Favorite.keep(@user, again)
    assert_equal 1, @user.favorites.count
    assert_equal "2026-09-08", first.reload.period_key
  end

  test "每人一份" do
    Favorite.keep(@user, @item)
    Favorite.keep(users(:guest), @item)

    assert_equal 1, @user.favorites.count
    assert_equal 1, users(:guest).favorites.count
  end

  # AC-10.3 管理员重抓把这一栏的条目行整个换掉，新内容不再含这条链接
  test "重抓换掉条目行，收藏还在" do
    favorite = Favorite.keep(@user, @item)

    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Another", url: "https://h.example/other", rank: 1) ])

    assert_not Item.exists?(@item.id)
    assert_equal "Show HN: A terminal log viewer written in Rust", favorite.reload.title
    assert_equal [ favorite ], @user.favorites.listed.to_a
    assert_empty Favorite.live_items([ favorite ])
  end

  # 重抓后这条链接还在榜上：条目 id 换了，仍然按（刊物、周期键、来源、链接）对得上
  test "live_items 对上重抓之后的新条目行" do
    favorite = Favorite.keep(@user, @item)

    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Show HN: renamed", url: @item.url, rank: 1) ])

    live = Favorite.live_items([ favorite ])[favorite.live_key]
    assert_not_equal @item.id, live.id
    assert_equal "Show HN: renamed", live.title
  end

  # R-10.9、AC-10.13
  test "listed 不含链接被下架的收藏，恢复上架后回来" do
    favorite = Favorite.keep(@user, @item)

    @item.update!(hidden: true)
    assert_empty @user.favorites.listed
    assert_equal 1, @user.favorites.count

    @item.update!(hidden: false)
    assert_equal [ favorite ], @user.favorites.listed.to_a
  end

  test "newest_first 按收藏时间倒序" do
    older = travel_to(2.days.ago) { Favorite.keep(@user, @item) }
    newer = Favorite.keep(@user, weekly_item)

    assert_equal [ newer, older ], @user.favorites.newest_first.to_a
  end

  # R-10.7 取消是真删；凭凭据把同一条原样插回去，id 与收藏时间不变
  test "取消后凭凭据原样恢复" do
    favorite = travel_to(3.days.ago) { Favorite.keep(@user, @item) }
    token = favorite.undo_token
    favorite.destroy!

    restored = Favorite.restore(@user, token)

    assert_equal favorite.id, restored.id
    assert_equal favorite.created_at, restored.created_at
    assert_equal favorite.attributes, restored.reload.attributes
  end

  test "条目已经被重抓换掉也能恢复" do
    favorite = Favorite.keep(@user, @item)
    token = favorite.undo_token
    favorite.destroy!
    issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "Another", url: "https://h.example/other", rank: 1) ])

    assert_equal favorite.id, Favorite.restore(@user, token).id
  end

  test "别人的、改过的、过期的凭据都恢复不了" do
    favorite = Favorite.keep(@user, @item)
    token = favorite.undo_token
    favorite.destroy!

    assert_nil Favorite.restore(users(:guest), token)
    assert_nil Favorite.restore(@user, token + "x")
    assert_nil Favorite.restore(@user, "")
    assert_nil Favorite.restore(@user, nil)
    travel_to(2.days.from_now) { assert_nil Favorite.restore(@user, token) }
    assert_equal 0, Favorite.count
  end

  test "这期间同一链接又被收藏过，恢复返回现有那条" do
    old = travel_to(3.days.ago) { Favorite.keep(@user, @item) }
    token = old.undo_token
    old.destroy!
    current = Favorite.keep(@user, @item)

    assert_equal current, Favorite.restore(@user, token)
    assert_equal 1, @user.favorites.count
  end
end
