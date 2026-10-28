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

  test "搜到周刊条目，所在期直达条目并保留板块作为回退" do
    issues(:weekly_w36).replace_section!(sources(:ruanyf), [ entry("慢下来的理由", section: "本周话题", rank: 1), entry("一个终端下的日志工具", section: "工具", rank: 2) ], issue_no: 366)
    item = issues(:weekly_w36).items.find_by!(title: "一个终端下的日志工具")

    visit search_path(q: "终端工具")

    assert_text "1 条结果"
    click_on "所在期 · 2026年 · 第 36 周 · 工具"

    assert_current_path weekly_issue_path("2026-W36", section: "issue-366-工具")
    assert_selector "section[id='issue-366-%E5%B7%A5%E5%85%B7'] h3", text: "工具"
    assert_equal "#item-#{item.id}", evaluate_script("window.location.hash")
  end

  test "长板块的搜索落点与重抓后的回退都能在视口中找到" do
    entries = (1..45).map { |rank| entry(rank == 20 ? "唯一检索目标" : "普通工具 #{rank}", section: "工具", rank: rank) }
    issues(:weekly_w36).replace_section!(sources(:ruanyf), entries, issue_no: 366)
    target = issues(:weekly_w36).items.find_by!(title: "唯一检索目标")
    path = weekly_issue_path("2026-W36", section: "issue-366-工具", anchor: "item-#{target.id}")
    [ 320, 375, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit search_path(q: "唯一检索目标")
      click_on "所在期 · 2026年 · 第 36 周 · 工具"
      assert_current_path weekly_issue_path("2026-W36", section: "issue-366-工具")
      assert_selector "article#item-#{target.id}:focus"
      wait_until { evaluate_script("(() => { const top = document.getElementById('item-#{target.id}').getBoundingClientRect().top; return top >= 0 && top < 80 })()") }
      assert_operator evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{width}px 横向溢出"
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      assert_selector "article#item-#{target.id} .item-title a:focus"
    end

    issues(:weekly_w36).replace_section!(sources(:ruanyf), entries.reject { |entry| entry.title == "唯一检索目标" }, issue_no: 366)
    visit search_path(q: "普通工具")
    visit path
    assert_selector "section[id='issue-366-%E5%B7%A5%E5%85%B7'] #item-#{target.id}[aria-hidden=true]", visible: :all
    wait_until { evaluate_script("(() => { const top = document.getElementById('item-#{target.id}').getBoundingClientRect().top; return top >= 0 && top < 80 })()") }
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "日刊的所在期落到条目并切到对应来源" do
    visit search_path(q: "terminal")

    click_on "所在期 · 2026年9月8日"

    assert_current_path daily_issue_path("2026-09-08", source: sources(:hn).id)
    assert_selector "article#item-#{items(:hn_one).id}", text: "Show HN"
  end

  test "键盘打开周刊条目时高对比度模式保留焦点提示" do
    issues(:weekly_w36).replace_section!(sources(:ruanyf), [ entry("键盘检索目标", section: "工具", rank: 1) ], issue_no: 366)
    item = issues(:weekly_w36).items.find_by!(title: "键盘检索目标")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    visit search_path(q: "键盘检索目标")
    find_link("所在期 · 2026年 · 第 36 周 · 工具").send_keys(:enter)
    assert_selector "article#item-#{item.id}:focus"
    assert_equal "solid", evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "长搜索页从第十三条所在期返回，恢复该链接与滚动位置并继续 Tab" do
    entries = (1..16).map { |rank| entry("historyfocus result #{rank}", section: "工具", rank: rank) }
    issues(:weekly_w36).replace_section!(sources(:ruanyf), entries, issue_no: 366)
    visit search_path(q: "historyfocus")
    assert_text "16 条结果"
    evaluate_async_script("document.fonts.ready.then(arguments[0])")
    target = all(".search-links > a:first-child")[12]
    execute_script("arguments[0].scrollIntoView({ block: 'center' }); arguments[0].focus({ preventScroll: true })", target)
    reading_position = evaluate_script("scrollY")
    assert_operator reading_position, :>, 500
    wait_until { evaluate_script("history.state.documentScrollPosition?.top") == reading_position }
    with_network_latency(250) do
      target.send_keys(:enter)
      assert_current_path weekly_issue_path("2026-W36", section: "issue-366-工具")
      assert_selector "section[id='issue-366-%E5%B7%A5%E5%85%B7'] h3", text: "工具"
    end

    page.go_back
    assert_current_path search_path(q: "historyfocus")
    assert_selector ".search-row:nth-child(13) .search-links > a:first-child:focus"
    wait_until { (evaluate_script("scrollY") - reading_position).abs < 2 }
    assert evaluate_script("(() => { const rect = document.activeElement.getBoundingClientRect(); return rect.top >= 0 && rect.bottom <= innerHeight })()")
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    assert_selector ".search-row:nth-child(13) .favorite-button:focus"
    assert_in_delta reading_position, evaluate_script("scrollY"), 2

    page.go_forward
    assert_current_path weekly_issue_path("2026-W36", section: "issue-366-工具")
    page.go_back
    assert_selector ".search-row:nth-child(13) .search-links > a:first-child:focus"

    find(".filters").click_on "日刊"
    assert_current_path search_path(q: "historyfocus", type: "daily")
    assert_selector ".filters .seg-item:focus", text: "日刊"
    fill_in "搜索", with: "terminal"
    find_field("搜索").send_keys(:enter)
    assert_current_path search_path(q: "terminal", type: "daily")
    assert_selector "#search-query:focus"
  end

  test "返回搜索后收藏保留结果锚点、未提交草稿与再次往返的焦点" do
    visit search_path(q: "terminal")
    click_on "所在期 · 2026年9月8日"
    assert_current_path daily_issue_path("2026-09-08", source: sources(:hn).id)

    page.go_back
    target_id = "search-result-#{items(:hn_one).id}"
    assert_selector "a##{target_id}:focus"
    fill_in "搜索", with: "unfinished draft"
    find(".search-mark").click
    assert_selector ".search-mark[data-on]:focus"
    wait_until { users(:drew).favorites.count == 1 }
    wait_for_favorite_requests(1)
    assert_equal "##{target_id}", evaluate_script("location.hash")
    assert_field "搜索", with: "unfinished draft"

    page.go_forward
    assert_current_path daily_issue_path("2026-09-08", source: sources(:hn).id)
    page.go_back
    assert_selector "a##{target_id}:focus"
    assert_selector ".search-mark[data-on]"
  end

  test "同一查询词的筛选历史同步搜索框并保留筛选焦点" do
    visit search_path(q: "rust")

    find(".filters").click_on "日刊"
    assert_current_path search_path(q: "rust", type: "daily")
    assert_selector ".filters .seg-item:focus", text: "日刊"

    fill_in "搜索", with: "draft"

    page.go_back
    assert_current_path search_path(q: "rust")
    assert_field "搜索", with: "rust"

    page.go_forward
    assert_current_path search_path(q: "rust", type: "daily")
    assert_field "搜索", with: "rust"
  end

  test "筛选跨屏宽隐藏控件时接续键盘焦点" do
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit search_path(q: "terminal")
    # 多个 headless 会话后目标文档可能未激活；显式模拟 focused/active 页面，验证页面内交接。
    browser.execute_cdp("Emulation.setFocusEmulationEnabled", enabled: true)
    assert evaluate_script("document.hasFocus()")
    source = find(".chips button", text: sources(:hn).name)
    execute_script("arguments[0].focus({ preventScroll: true })", source)
    assert_selector ".chips button:focus", text: sources(:hn).name

    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 900, deviceScaleFactor: 1, mobile: false)
    assert_selector ".filter-toggle:focus"
    toggle = find(".filter-toggle")
    execute_script("arguments[0].focus({ preventScroll: true })", toggle)
    assert_selector ".filter-toggle:focus"

    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    assert_selector ".filters nav[aria-label='刊物'] .seg-item:first-child:focus", text: "全部"
    assert_no_selector ".filter-toggle", visible: :all
    assert_field "搜索", with: "terminal"
    assert_current_path search_path(q: "terminal")
  ensure
    begin
      browser&.execute_cdp("Emulation.setFocusEmulationEnabled", enabled: false)
    ensure
      browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
  end

  # test 环境默认关掉 CSRF 校验（config/environments/test.rb 的 allow_forgery_protection = false）：
  # 这一条把它打开，fetch 带的 X-CSRF-Token 才真的被校验，令牌读错了这里就会是 422 而不是 204
  test "点标题打开原文并记一次 search_click，带 CSRF 令牌" do
    with_forgery_protection do
      visit search_path(q: "terminal")

      find(".search-title a", match: :first).click

      wait_until { Search::Click.count == 1 }
      click = Search::Click.sole
      assert_equal items(:hn_one), click.item
      assert_equal 1, click.rank
      assert_equal "terminal", click.query
    end
  end

  private
    def with_network_latency(milliseconds)
      page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: milliseconds, downloadThroughput: -1, uploadThroughput: -1)
      yield
    ensure
      page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1)
    end
end
