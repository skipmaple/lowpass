require "application_system_test_case"

# P0 出口：真的在浏览器里读一期日刊。切来源是页面本地状态（条目全在 props 里，不回服务端），
# 集成测试只看得到第一屏的 payload，验不出切换这件事。
class ReadingTest < ApplicationSystemTestCase
  HN_TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  test "读一期日刊并切到另一个来源" do
    visit daily_issue_path("2026-09-08")

    assert_text HN_TITLE

    click_on sources(:github).name

    assert_no_text HN_TITLE
    # fixture 里 GitHub Trending 那一栏是 failed：附录 B 的「今日抓取失败，已通知管理员」
    assert_text "今日抓取失败，已通知管理员"
  end

  # D20：`/` 就是最新一期日刊，没有单独的首页
  test "首页落到最新一期" do
    visit root_path

    assert_current_path daily_issue_path("2026-09-08")
    assert_text "9月8日"
  end
end
