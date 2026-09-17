require "application_system_test_case"

# P1 出口：真的在浏览器里搜到一条，点「所在期」落到那一期的对应位置（AC-4.4），点原文记一次 search_click（9.1，
# 这一条顺带验的是 fetch 带 CSRF 令牌那条路）。
class SearchingTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
    Rails.cache.clear
    Search::Record.rebuild!
  end

  def entry(title, section:, rank:)
    Adapters::Entry.new(title: title, url: "https://r.example/#{rank}", section: section, rank: rank,
                        meta: { issue_no: 366, issue_title: "慢下来的理由", anchor: section })
  end

  test "AC-4.4 搜到周刊条目，所在期落到周刊页的板块锚点" do
    issues(:weekly_w36).replace_section!(sources(:ruanyf), [ entry("慢下来的理由", section: "本周话题", rank: 1), entry("一个终端下的日志工具", section: "工具", rank: 2) ], issue_no: 366)

    visit search_path(q: "终端工具")

    assert_text "1 条结果"
    click_on "所在期 · 第 36 周 · 工具"

    assert_current_path weekly_issue_path("2026-W36")
    assert_selector "section[id='issue-366-%E5%B7%A5%E5%85%B7'] h3", text: "工具"
    assert_includes evaluate_script("window.location.hash"), "issue-366-"
  end

  test "日刊的所在期落到条目并切到对应来源" do
    visit search_path(q: "terminal")

    click_on "所在期 · 9月8日"

    assert_current_path daily_issue_path("2026-09-08", source: sources(:hn).id)
    assert_selector "article#item-#{items(:hn_one).id}", text: "Show HN"
  end

  test "筛选使用未提交的搜索词且浏览器前进后退同步搜索框" do
    visit search_path(q: "terminal")
    fill_in "搜索", with: "rust"

    find(".filters").click_on "Hacker News"
    assert_current_path search_path(q: "rust", source: sources(:hn).id)
    assert_field "搜索", with: "rust"

    page.go_back
    assert_current_path search_path(q: "terminal")
    assert_field "搜索", with: "terminal"

    page.go_forward
    assert_current_path search_path(q: "rust", source: sources(:hn).id)
    assert_field "搜索", with: "rust"
  end

  # test 环境默认关掉 CSRF 校验（config/environments/test.rb 的 allow_forgery_protection = false）：
  # 这一条把它打开，fetch 带的 X-CSRF-Token 才真的被校验，令牌读错了这里就会是 422 而不是 204
  test "点原文记一次 search_click，带 CSRF 令牌" do
    with_forgery_protection do
      visit search_path(q: "terminal")

      click_on "原文"

      Timeout.timeout(5) { sleep 0.1 until Search::Click.count == 1 }
      click = Search::Click.sole
      assert_equal items(:hn_one), click.item
      assert_equal 1, click.rank
      assert_equal "terminal", click.query
    end
  end

  private
    def with_forgery_protection
      was = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = was
    end
end
