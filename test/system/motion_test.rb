require "application_system_test_case"

# 动效（设计说明 2026-10-14 第 4.4 节）里要在真页面上量的部分
class MotionTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
  end

  test "M1 墨块跟着当前来源：副本的裁切与当前项重合，切换后滑到新来源" do
    visit daily_issue_path("2026-09-08")
    assert_selector ".source-tabs-frame[data-ink]"
    assert_ink_on sources(:hn).name

    find(".source-tabs:not(.source-tabs-ink)").click_on sources(:hackaday).name
    assert_ink_on sources(:hackaday).name
  end

  test "M1 连点两个来源，墨块最后停在第二个上" do
    visit daily_issue_path("2026-09-08")

    find(".source-tabs:not(.source-tabs-ink)").click_on sources(:github).name
    find(".source-tabs:not(.source-tabs-ink)").click_on sources(:hackaday).name
    assert_ink_on sources(:hackaday).name
  end

  test "M1 手机宽度同样对齐" do
    with_viewport(375, 812) do
      visit daily_issue_path("2026-09-08")
      find(".source-tabs:not(.source-tabs-ink)").click_on sources(:github).name
      assert_ink_on sources(:github).name
    end
  end

  test "M8 ← 到前一期，→ 回到后一期；最新一期按 → 不动；输入框里按 ← 不翻" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    visit daily_issue_path("2026-09-08")

    find("body").send_keys(:right)
    assert_current_path daily_issue_path("2026-09-08")

    find("body").send_keys(:left)
    assert_current_path daily_issue_path("2026-09-07")
    assert_no_selector "html[data-vt]", visible: :all, wait: 2

    find("body").send_keys(:right)
    assert_current_path daily_issue_path("2026-09-08")

    find("a[aria-label='搜索']").click
    find("input[type='search']").send_keys(:left)
    assert_current_path search_path
  end

  test "M2 前一期按钮带方向与键盘提示" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    visit daily_issue_path("2026-09-08")

    assert_selector ".issue-nav a.ctrl[aria-keyshortcuts='ArrowLeft']", text: "前一期"
    find(".issue-nav a.ctrl", text: "前一期").click
    assert_current_path daily_issue_path("2026-09-07")
  end

  private
    # 等过渡跑完，再比副本露出的矩形（inline style 里设的 inset）与当前项的矩形
    def assert_ink_on(name)
      wait_until do
        evaluate_script(<<~JS)
          (() => {
            const frame = document.querySelector('.source-tabs-frame').getBoundingClientRect()
            const tab = [...document.querySelectorAll('.source-tabs:not(.source-tabs-ink) [role="tab"]')].find((t) => t.textContent.includes(#{name.to_json}))
            const ink = document.querySelector('.source-tabs-ink')
            if (!tab || !ink || tab.getAttribute('aria-selected') !== 'true' || ink.getAnimations().length) return false
            const values = ink.style.clipPath.match(/inset\\(([^)]*)\\)/)[1].split(/\\s+/).map(parseFloat)
            const [top, right = top, bottom = top, left = right] = values
            const r = tab.getBoundingClientRect()
            const near = (a, b) => Math.abs(a - b) <= 1
            return near(left, r.left - frame.left) && near(top, r.top - frame.top) && near(frame.width - right, r.right - frame.left) && near(frame.height - bottom, r.bottom - frame.top)
          })()
        JS
      end
    end

    def with_viewport(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      yield
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
end
