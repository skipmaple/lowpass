require "application_system_test_case"

class SearchStartupTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }

  teardown do
    page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: false)
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1)
  end

  test "搜索页在入口执行前声明页面模块，冷缓存可并行下载" do
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: true)
    page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 120, downloadThroughput: 625_000, uploadThroughput: 625_000)
    visit search_path
    assert_selector "h1", text: "搜索"

    manifest = ViteRuby.instance.manifest
    search = manifest.resolve_entries("pages/Search/Show.tsx")
    application = manifest.resolve_entries("application.tsx", type: :typescript)
    search_only = (search.fetch(:scripts) + search.fetch(:imports)) - (application.fetch(:scripts) + application.fetch(:imports))
    declared = all("link[rel='modulepreload'][data-search-page]", visible: :all).map { |link| URI(link[:href]).path }
    assert_equal search_only.sort, declared.sort, "搜索模块及其专属依赖都应预加载"
    search_only.each do |path|
      requests = evaluate_script("performance.getEntriesByType('resource').filter(entry => new URL(entry.name).pathname === arguments[0]).length", path)
      assert_equal 1, requests, "预加载的资源不应重复下载"
      before_entry_finishes = evaluate_script(<<~JS, path)
        (() => {
          const resources = performance.getEntriesByType('resource')
          const pageModule = resources.find(entry => new URL(entry.name).pathname === arguments[0])
          const entry = resources.find(entry => entry.name === document.querySelector('script[data-startup-entry]').src)
          return !!pageModule && !!entry && pageModule.startTime < entry.responseEnd
        })()
      JS
      assert before_entry_finishes, "搜索资源应在入口下载结束前启动"
    end

    page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1)
    visit daily_issue_path("2026-09-08")
    assert_no_selector "link[data-search-page]", visible: :all
  end
  test "搜索模块不可用时仍显示原生重载入口" do
    script = ViteRuby.instance.manifest.resolve_entries("pages/Search/Show.tsx").fetch(:scripts).first
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*#{File.basename(script)}*" ])
    visit search_path(q: "Rust")

    assert_selector "#startup-recovery", text: "页面尚未加载完成", wait: 10
    assert_link "重新加载", href: search_path(q: "Rust")
    assert_no_selector "#app > *"
  end
end
