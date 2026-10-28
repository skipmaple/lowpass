require "application_system_test_case"

class ForcedColorFocusTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "高对比模式下选中项与键盘焦点同时可见" do
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit search_path
    assert_field "搜索"
    visual = evaluate_script(<<~JS)
      (() => {
        const search = document.querySelector('.search-field > svg');
        const stamp = document.querySelector('footer svg');
        return { search: getComputedStyle(search).stroke, stamp: getComputedStyle(stamp).stroke, stampText: getComputedStyle(stamp.querySelector('text')).fill,
                 text: getComputedStyle(document.body).color, canvas: getComputedStyle(document.documentElement).backgroundColor };
      })()
    JS
    assert_equal visual.fetch("text"), visual.fetch("search"), "搜索图标应采用系统前景色"
    assert_equal visual.fetch("text"), visual.fetch("stamp"), "页脚图形应采用系统前景色"
    assert_equal visual.fetch("text"), visual.fetch("stampText"), "页脚文字应采用系统前景色"
    fill_in "搜索", with: "Rust"
    clear_colors = evaluate_script("[getComputedStyle(document.querySelector('.search-clear')).color, getComputedStyle(document.querySelector('.search-clear svg')).stroke]")
    assert_equal clear_colors.first, clear_colors.last, "清除图标应继承按钮的系统色"
    find(".search-clear").click
    assert_field "搜索", with: ""
    selected = find(".filters nav[aria-label='刊物'] .seg-item[aria-current='true']")
    before = evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", selected)
    find_field("搜索").send_keys(:tab, :tab)
    assert_selector ".filters nav[aria-label='刊物'] .seg-item[aria-current='true']:focus-visible"
    focused = evaluate_script(<<~JS, selected)
      (() => { const s = getComputedStyle(arguments[0]); return { offset: s.outlineOffset, border: getComputedStyle(arguments[0], '::after').borderTopWidth }; })()
    JS
    assert_equal "3px", before, "选中项应有内侧标记"
    assert_equal "2px", focused.fetch("offset"), "焦点应在选中标记之外"
    assert_equal "3px", focused.fetch("border"), "焦点出现时仍要保留选中标记"

    browser.action.send_keys(:tab, :tab, :tab).perform
    assert_selector ".chips button:focus-visible", text: sources(:hn).name
    browser.action.send_keys(:space).perform
    assert_selector ".chips button[aria-pressed='true']:focus-visible", text: sources(:hn).name
    chip = find(".chips button[aria-pressed='true']", text: sources(:hn).name)
    assert_equal "2px", evaluate_script("getComputedStyle(arguments[0]).outlineOffset", chip)
    assert_equal "3px", evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", chip)
  end
  test "窄屏展开筛选后，选中与键盘焦点仍可同时辨认" do
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
    visit search_path
    find(".filter-toggle").click
    target = find(".filters nav[aria-label='刊物'] .seg-item[aria-current='true']")
    find_field("搜索").click
    8.times do
      break if evaluate_script("document.activeElement === arguments[0]", target)
      browser.action.send_keys(:tab).perform
    end
    assert_selector ".filters nav[aria-label='刊物'] .seg-item[aria-current='true']:focus-visible"
    assert_equal "2px", evaluate_script("getComputedStyle(arguments[0]).outlineOffset", target)
    assert_equal "3px", evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", target)
    assert evaluate_script("document.documentElement.scrollWidth <= innerWidth")
  end

  test "后台选中导航也保留独立的键盘焦点" do
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    visit "/admin"
    target = find(".admin-nav-item[aria-current='page']")
    30.times do
      break if evaluate_script("document.activeElement === arguments[0]", target)
      browser.action.send_keys(:tab).perform
    end
    assert_selector ".admin-nav-item[aria-current='page']:focus-visible"
    assert_equal "2px", evaluate_script("getComputedStyle(arguments[0]).outlineOffset", target)
    assert_equal "3px", evaluate_script("getComputedStyle(arguments[0], '::after').borderTopWidth", target)
  end

  test "高对比模式下日刊来源链接和失败状态的图标继承系统色" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    visit daily_issue_path("2026-09-08")
    assert_selector ".source-foot svg"
    assert_selector ".source-state-failed svg"
    icons = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.source-foot svg, .source-state-failed svg')).map(icon => ({
        stroke: getComputedStyle(icon).stroke, color: getComputedStyle(icon).color
      }))
    JS
    assert icons.all? { |icon| icon.fetch("stroke") == icon.fetch("color") }, icons.inspect
    sun = evaluate_script(<<~JS)
      (() => {
        const svg = document.querySelector('.source-state-art');
        return { color: getComputedStyle(svg).color, sun: getComputedStyle(svg.querySelector('.sunrise-sun path[fill]')).fill,
                 canvas: getComputedStyle(document.documentElement).backgroundColor, paper: getComputedStyle(svg.querySelector('rect[fill]')).fill };
      })()
    JS
    assert_equal sun.fetch("color"), sun.fetch("sun")
    assert_equal sun.fetch("canvas"), sun.fetch("paper")
  end

  test "高对比模式下来源图形的挖空与强调使用系统颜色" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    visit daily_issue_path("2026-09-08")
    assert_selector ".daily-source-icon", count: 3
    details = evaluate_script(<<~JS)
      (() => {
        const svgs = Array.from(document.querySelectorAll('.daily-source-icon'));
        const ink = svgs.flatMap(svg => Array.from(svg.querySelectorAll('[fill="var(--ink)"], [fill="var(--green)"]')).map(el => ({ value: getComputedStyle(el).fill, expected: getComputedStyle(svg).color })));
        const holes = svgs.flatMap(svg => Array.from(svg.querySelectorAll('[fill="var(--paper)"]')).map(el => getComputedStyle(el).fill));
        return { ink, holes, canvas: getComputedStyle(document.documentElement).backgroundColor };
      })()
    JS
    assert_not_empty details.fetch("ink")
    assert_not_empty details.fetch("holes")
    assert details.fetch("ink").all? { |entry| entry.fetch("value") == entry.fetch("expected") }, details.inspect
    assert details.fetch("holes").all? { |color| color == details.fetch("canvas") }, details.inspect

    entry = Adapters::Entry.new(title: "本期话题", url: "https://example.com/story", section: "本周话题", rank: 1,
      meta: { issue_no: 366, issue_title: "慢下来的理由", anchor: "本周话题" })
    issues(:weekly_w36).replace_section!(sources(:ruanyf), [ entry ], issue_no: 366)
    visit weekly_issue_path("2026-W36")
    assert_selector ".source-band-mark"
    values = evaluate_script(<<~JS)
      (() => {
        const svg = document.querySelector('.source-band-mark');
        return { paper: getComputedStyle(svg.querySelector('[fill="var(--band-hole)"]')).fill,
                 canvas: getComputedStyle(document.documentElement).backgroundColor };
      })()
    JS
    assert_equal values.fetch("canvas"), values.fetch("paper")
  end

  test "高对比模式下缺页插图使用系统前景与背景色" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    visit "/this-page-does-not-exist"
    assert_selector ".error-art svg"
    values = evaluate_script(<<~JS)
      (() => {
        const svg = document.querySelector('.error-art svg');
        return { color: getComputedStyle(svg).color, stroke: getComputedStyle(svg).stroke,
                 canvas: getComputedStyle(document.documentElement).backgroundColor, paper: getComputedStyle(svg.querySelector('path[fill]')).fill };
      })()
    JS
    assert_equal values.fetch("color"), values.fetch("stroke")
    assert_equal values.fetch("canvas"), values.fetch("paper")
  end

  test "正常配色下图标仍沿用墨色" do
    visit search_path
    assert_field "搜索"
    colors = evaluate_script(<<~JS)
      (() => {
        const ink = getComputedStyle(document.body).color;
        return [ink, getComputedStyle(document.querySelector('.search-field > svg')).stroke,
          getComputedStyle(document.querySelector('footer svg')).stroke,
          getComputedStyle(document.querySelector('footer svg text')).fill];
      })()
    JS
    assert_equal [ colors.first ] * 4, colors
  end
end
