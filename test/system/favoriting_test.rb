require "application_system_test_case"

# P4 出口：真的在浏览器里收藏一条、从头像菜单进收藏页、取消再恢复（AC-10.1、10.4、10.12）。
# 书签的请求是 fetch 发的：集成测试看不到前端那一半，这里把 CSRF 校验也打开——令牌读错了就是 422，书签会回滚
class FavoritingTest < ApplicationSystemTestCase
  TITLE = "Show HN: A terminal log viewer written in Rust".freeze

  setup do
    sign_in_with_browser(users(:drew))
  end

  test "收藏一条，从头像菜单进收藏页，取消后恢复" do
    with_forgery_protection do
      visit daily_issue_path("2026-09-08")

      find("button[aria-label='收藏：#{TITLE}']").click
      assert_selector "button[aria-label='取消收藏：#{TITLE}'][data-on]"
      wait_until { users(:drew).favorites.count == 1 }

      find("button[aria-label='账户']").click
      within(".menu-card") { click_on "收藏" }

      assert_current_path favorites_path
      assert_selector "h1", text: "收藏"
      assert_selector ".search-row", text: TITLE

      find("button[aria-label='取消收藏：#{TITLE}']").click
      assert_text "已取消收藏"
      wait_until { users(:drew).favorites.count.zero? }

      click_on "恢复"
      assert_no_text "已取消收藏"
      assert_selector "button[aria-label='取消收藏：#{TITLE}'][data-on]"
      wait_until { users(:drew).favorites.count == 1 }

      refresh
      assert_selector ".search-row", text: TITLE
    end
  end

  # R-10.7：收藏页上取消后离开再回来，那一行不再出现；回到所在期，条目是未收藏
  test "取消后刷新，那一行不再出现，所在期里的书签回到未收藏" do
    Favorite.keep(users(:drew), items(:hn_one))
    visit favorites_path

    find("button[aria-label='取消收藏：#{TITLE}']").click
    assert_text "已取消收藏"
    wait_until { users(:drew).favorites.count.zero? }

    refresh
    assert_text "还没有收藏。"

    click_on "阅读最新日刊"
    assert_current_path daily_issue_path("2026-09-08")
    assert_selector "button[aria-label='收藏：#{TITLE}']"
    assert_no_selector "button[aria-label='取消收藏：#{TITLE}']"
  end

  # 离开再按后退：恢复出来的页面与服务端一致（书签的状态写回了 Inertia 当前页）
  test "收藏后离开再后退，书签仍是已收藏" do
    visit daily_issue_path("2026-09-08")

    find("button[aria-label='收藏：#{TITLE}']").click
    wait_until { users(:drew).favorites.count == 1 }

    find("a[aria-label='搜索']").click
    assert_current_path search_path

    page.go_back
    assert_current_path daily_issue_path("2026-09-08")
    assert_selector "button[aria-label='取消收藏：#{TITLE}'][data-on]"
  end

  # AC-10.14：手机宽度下书签仍是 44 见方的目标，页面不横向溢出
  test "手机宽度下书签是 44 见方，页面不横向溢出" do
    with_viewport(375, 812) do
      visit daily_issue_path("2026-09-08")

      assert_selector ".favorite-button"
      assert_equal 375, evaluate_script("window.innerWidth")
      width, height = evaluate_script("(() => { const box = document.querySelector('.favorite-button').getBoundingClientRect(); return [box.width, box.height] })()")
      assert_operator width, :>=, 44
      assert_operator height, :>=, 44
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, 375
    end
  end

  private
    # 无头 Chrome 的窗口宽度收不到 500px 以下（resize_to(375, 812) 实际得到 500）：
    # 要在手机宽度的视口里量，用 CDP 把设备尺寸定住，量完清掉
    def with_viewport(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      yield
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
end
