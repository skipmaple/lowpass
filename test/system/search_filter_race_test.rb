require "application_system_test_case"

class SearchFilterRaceTest < ApplicationSystemTestCase
  # 只等待本测试的前两次筛选请求：第二次到达后才放行第一轮，确保不是顺序成功。
  class OverlappingSearches
    def initialize(app)
      @app = app
      @mutex = Mutex.new
      @changed = ConditionVariable.new
      @armed = false
      @active = 0
    end

    def arm
      @mutex.synchronize do
        @started = 0
        @overlapped = false
        @armed = true
      end
    end

    def finish
      @mutex.synchronize do
        @armed = false
        @changed.broadcast
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        while @active.positive?
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise "filter request did not finish" if remaining <= 0
          @changed.wait(@mutex, remaining)
        end
      end
    end

    def overlapped? = @mutex.synchronize { @overlapped }
    def pending? = @mutex.synchronize { @active.positive? }

    def call(env)
      tracked = false
      @mutex.synchronize do
        if @armed && env["REQUEST_METHOD"] == "GET" && env["PATH_INFO"] == "/search" && env["HTTP_X_INERTIA"] == "true"
          tracked = true
          @active += 1
          @started += 1
          @changed.broadcast
          if @started == 1
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
            while @armed && @started < 2
              remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
              break if remaining <= 0
              @changed.wait(@mutex, remaining)
            end
            @overlapped = @started >= 2
          end
        end
      end
      @app.call(env)
    ensure
      if tracked
        @mutex.synchronize do
          @active -= 1
          @changed.broadcast
        end
      end
    end
  end

  setup do
    @original_app = Capybara.app
    @overlapping_searches = OverlappingSearches.new(@original_app)
    Capybara.app = @overlapping_searches
    sign_in_with_browser(users(:drew))
    Search::Record.rebuild!
  end

  teardown do
    begin
      @overlapping_searches&.finish
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    ensure
      Capybara.app = @original_app
    end
  end

  test "已有结果切换排序时加载提示替换计数且不推移结果" do
    [ 320, 375, 768, 1440 ].each do |width|
      at_width(width)
      visit search_path(q: "terminal")
      assert_selector ".search-row"
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      before = evaluate_script("document.querySelector('.search-row').getBoundingClientRect().top")

      @overlapping_searches.arm
      find(".search-count").click_on "时间"
      wait_until { @overlapping_searches.pending? }
      assert_selector ".search-count", text: "正在搜索…"
      assert_no_selector ".search-loading", visible: true
      assert_in_delta before, evaluate_script("document.querySelector('.search-row').getBoundingClientRect().top"), 0.5, "#{width}px 加载时结果不移动"
      @overlapping_searches.finish
      assert_current_path search_path(q: "terminal", sort: "date")
      assert_selector ".search-count", text: "条结果"
    end
  end

  test "响应未返回前填写起止日期仍提交完整区间" do
    [ 375, 1440 ].each do |width|
      at_width(width)
      visit search_path(q: "terminal", from: "2026-08-01", to: "2026-10-01", range: "custom")
      open_filters

      with_overlapping_searches do
        set_date("起始日期", "2026-08-02")
        set_date("结束日期", "2026-09-10")
        find_field("搜索").click

        assert_search(q: "terminal", from: "2026-08-02", to: "2026-09-10", range: "custom")
        assert_equal "2026-08-02", date_field("起始日期").value
        assert_equal "2026-09-10", date_field("结束日期").value
        assert_text "1 条结果"
      end

      page.go_back
      assert_search(q: "terminal", from: "2026-08-01", to: "2026-10-01", range: "custom")
      open_filters
      assert_equal "2026-08-01", date_field("起始日期").value
      assert_equal "2026-10-01", date_field("结束日期").value
      page.go_forward
      assert_search(q: "terminal", from: "2026-08-02", to: "2026-09-10", range: "custom")
      open_filters
      assert_equal "2026-08-02", date_field("起始日期").value
      assert_equal "2026-09-10", date_field("结束日期").value
    end
  end

  test "响应未返回前连选两个来源仍保留两者" do
    [ 375, 1440 ].each do |width|
      at_width(width)
      visit search_path(q: "terminal")
      open_filters

      with_overlapping_searches do
        find(".chips button", text: sources(:hn).name).click
        find(".chips button", text: sources(:github).name).click

        assert_search(q: "terminal", source: "#{sources(:hn).id},#{sources(:github).id}")
        assert_selector ".chips button[aria-pressed='true']", text: sources(:hn).name
        assert_selector ".chips button[aria-pressed='true']", text: sources(:github).name
        assert_text "1 条结果"
      end
    end
  end

  test "来源响应未返回前切排序仍保留所选来源" do
    [ 375, 1440 ].each do |width|
      at_width(width)
      visit search_path(q: "terminal")
      open_filters

      with_overlapping_searches do
        find(".chips button", text: sources(:hn).name).click
        within("nav[aria-label='排序']") { click_on "时间" }

        assert_search(q: "terminal", source: sources(:hn).id, sort: "date")
        open_filters
        assert_selector ".chips button[aria-pressed='true']", text: sources(:hn).name
        assert_selector "nav[aria-label='排序'] a[aria-current='true']", text: "时间"
      end
    end
  end

  test "排序响应未返回前选来源仍保留排序" do
    [ 375, 1440 ].each do |width|
      at_width(width)
      visit search_path(q: "terminal")
      open_filters

      with_overlapping_searches do
        within("nav[aria-label='排序']") { click_on "时间" }
        find(".chips button", text: sources(:hn).name).click

        assert_search(q: "terminal", source: sources(:hn).id, sort: "date")
        open_filters
        assert_selector ".chips button[aria-pressed='true']", text: sources(:hn).name
        assert_selector "nav[aria-label='排序'] a[aria-current='true']", text: "时间"
      end
    end
  end

  private
    def assert_search(params)
      expected = params.stringify_keys
      actual = nil
      assert_current_path search_path, ignore_query: true, wait: 5 do |uri|
        actual = Rack::Utils.parse_query(uri.query)
        actual == expected
      end
    rescue Minitest::Assertion
      raise if actual == expected
      flunk "expected search parameters #{expected.inspect}, got #{actual.inspect}"
    end

    def date_field(label)
      find("input[type='date'][aria-label='#{label}']")
    end

    # Selenium 的日期字符串受系统区域格式影响；用原生 setter 发出输入事件，再由真实点击触发失焦提交。
    def set_date(label, value)
      input = date_field(label)
      input.click
      execute_script(<<~JS, input, value)
        Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(arguments[0], arguments[1]);
        arguments[0].dispatchEvent(new Event('input', { bubbles: true }));
        arguments[0].dispatchEvent(new Event('change', { bubbles: true }));
      JS
    end

    def at_width(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
    end

    def open_filters
      assert_selector ".filters-shell"
      if evaluate_script("matchMedia('(max-width: 480px)').matches")
        toggle = find(".filter-toggle")
        toggle.click if toggle["aria-expanded"] == "false"
      end
    end

    def with_overlapping_searches
      @overlapping_searches.arm
      yield
      assert @overlapping_searches.overlapped?, "second request must start before the first response"
    ensure
      @overlapping_searches.finish
    end
end
