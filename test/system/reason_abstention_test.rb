require "application_system_test_case"

class ReasonAbstentionSystemTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 9, 9, 4)
    @issue = issues(:daily_0908)
    @issue.update!(source_states: %i[ hn github hackaday ].index_with { "ok" }.transform_keys { |key| sources(key).id })
    @fresh = copy_item("Opaque title")
    @fresh.record_reason_abstention(assessed_at: Time.utc(2026, 9, 9, 1, 30))
    @retained = copy_item("Retained title", reason: "历史推荐理由，供前端开发读者考察工具边界。", interest_tag: "前端开发", title_zh: "历史标题译文")
    @retained.record_reason_abstention(assessed_at: Time.utc(2026, 9, 9, 1))
    copy_item("Written title", reason: "已有推荐理由，供前端开发读者考察工具边界。")
    Setting.set("model_base_url", "https://model.example/v1")
    Setting.set("model_name", "offline-test-model")
    Reasons::Provider.stubs(:api_key).returns("test-key")
    sign_in_with_browser(users(:drew))
    page.driver.browser.execute_cdp("Emulation.setFocusEmulationEnabled", enabled: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setFocusEmulationEnabled", enabled: false)
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "375 390 和桌面已有详情呈现四类与时间且键盘可到阅读页" do
    [ 375, 390, 1440 ].each do |width|
      viewport(width)
      visit admin_issues_path(month: "2026-09")
      row = find("[data-table-row-key='daily-2026-09-08']")
      row.find("summary", text: "刊物详情").click if width < 768
      within(row) do
        [ "已有理由 1 条", "资料不足未写 1 条", "保留旧理由 1 条（本次资料不足）", "缺 1 条", "最后处理 2026-09-09 09:30" ].each { |text| assert_text text }
        find("button[data-table-focus='reasons']").send_keys(:tab)
        assert_selector "a[data-table-focus='view']:focus"
        find("a[data-table-focus='view']").send_keys(:enter)
      end
      assert_current_path daily_issue_path("2026-09-08")
      assert_no_overflow
    end
  end

  test "未配置及空画像保留真实处理计数并禁用理由入口" do
    viewport(375)
    [ :unconfigured, :empty_profile ].each do |state|
      Setting.set("model_base_url", state == :unconfigured ? "" : "https://model.example/v1")
      InterestArea.update_all(enabled: state != :empty_profile)
      visit admin_issues_path(month: "2026-09")
      row = find("[data-table-row-key='daily-2026-09-08']")
      row.find("summary", text: "刊物详情").click
      within(row) do
        assert_text "资料不足未写 1 条"
        assert_text "保留旧理由 1 条（本次资料不足）"
        assert_text(state == :unconfigured ? "未配置模型供应商" : "兴趣画像为空")
        assert_button "重生成理由", disabled: true
      end
      assert_no_overflow
    end
  end

  test "减少动效时详情与过滤仍可用且合法拒写不是待处理" do
    viewport(390)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    items(:hn_one).record_reason_abstention(assessed_at: Time.current)
    visit admin_issues_path(kind: "daily", month: "2026-09")
    row = find("[data-table-row-key='daily-2026-09-08']")
    row.find("summary", text: "刊物详情").click
    assert_text "资料不足未写 2 条"
    check "待处理"
    assert_no_selector "[data-table-row-key='daily-2026-09-08']"
    assert_equal 0, ModelCall.count
    assert_no_overflow
  end

  test "读者新拒写静默且历史内容原样，原文和收藏仍可用" do
    viewport(390)
    visit daily_issue_path("2026-09-08")
    within("#item-#{@fresh.id}") do
      assert_link "Opaque title", href: @fresh.url
      assert_no_selector ".item-reason, .item-tag, .item-translation"
      assert_no_text "资料不足"
      find("button[aria-label='收藏：Opaque title']").click
      assert_selector "button[aria-label='取消收藏：Opaque title']"
    end
    wait_until { users(:drew).favorites.exists?(url_hash: @fresh.url_hash) }
    within("#item-#{@retained.id}") do
      assert_text @retained.reason
      assert_text "历史标题译文"
      assert_text "前端开发"
      assert_no_text "核验"
      assert_no_text "资料不足"
    end
    assert_no_overflow
  end

  private
    def copy_item(title, **attributes)
      item = items(:hn_one).dup
      item.assign_attributes(title: title, url: "https://example.test/#{title.parameterize}", url_hash: Digest::SHA256.hexdigest(title), **attributes)
      item.save!
      item
    end

    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
    end

    def assert_no_overflow
      evaluate_async_script("const done = arguments[0]; document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(done)))")
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, evaluate_script("innerWidth")
    end
end
