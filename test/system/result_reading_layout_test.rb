require "application_system_test_case"

class ResultReadingLayoutTest < ApplicationSystemTestCase
  THEMES = %w[ daybreak duet unfold ].freeze

  setup do
    @item = items(:hn_one)
    @item.update!(title: "Reading measure: a long technical headline that stays with its translated title and explanatory paragraph",
      title_zh: "阅读版心：长标题与译文及摘要保持在同一阅读列中",
      summary: "Reading measure keeps the title, paragraph and associated actions together.",
      summary_zh: "标题、说明和操作围绕同一条资料组织，保留完整的来源和原文线索。",
      reason: "可比较三种版式如何组织同一条资料的正文与原文线索。")
    Search::Record.rebuild!
    Favorite.keep(users(:drew), @item)
    sign_in_with_browser(users(:drew))
  end

  test "搜索与收藏保留三主题构图，资料与操作都在阅读区内" do
    THEMES.each do |theme|
      [ 1440, 1920 ].each do |width|
        viewport(width)
        [ search_path(q: "Reading measure"), favorites_path ].each do |path|
          visit_theme(theme, path)
          assert_selector ".record-title", text: @item.title_zh
          assert_selector ".search-snippet", text: @item.summary_zh
          geometry = evaluate_script(<<~JS)
            (() => {
              const row = document.querySelector('.library-record');
              const bounds = (node) => {
                const rect = node.getBoundingClientRect();
                return { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom, width: rect.width, height: rect.height };
              };
              const rect = (selector) => bounds(row.querySelector(selector));
              return { row: bounds(row), workspace: bounds(document.querySelector('.library-workspace')),
                heading: bounds(document.querySelector('.library-page > .page-head')),
                title: rect('.record-title'), meta: rect('.record-meta'), snippet: rect('.search-snippet'),
                rail: rect('.record-rail'), detail: rect('.record-detail'), actions: rect('.record-actions'),
                where: rect('.record-issue-link'), bookmark: rect('.favorite-button'),
                railVisible: getComputedStyle(row.querySelector('.record-rail')).display !== 'none',
                documentWidth: document.documentElement.scrollWidth, viewportWidth: innerWidth };
            })()
          JS
          message = "#{theme} #{path} at #{width}px: #{geometry}"
          assert_in_delta geometry.dig("row", "left"), geometry.dig("workspace", "left"), 1, message
          assert_in_delta geometry.dig("row", "right"), geometry.dig("workspace", "right"), 1, message
          assert_in_delta geometry.dig("title", "left"), geometry.dig("snippet", "left"), 1, message
          %w[title meta snippet actions where bookmark].each do |part|
            assert_operator geometry.dig(part, "left"), :>=, geometry.dig("row", "left") - 1, message
            assert_operator geometry.dig(part, "right"), :<=, geometry.dig("row", "right") + 1, message
          end
          assert_operator geometry.dig("bookmark", "width"), :>=, 44
          assert_operator geometry.dig("bookmark", "height"), :>=, 44
          assert_operator geometry.dig("where", "height"), :>=, 44
          assert_operator geometry.fetch("documentWidth"), :<=, geometry.fetch("viewportWidth"), message

          case theme
          when "daybreak"
            assert_operator geometry.dig("meta", "right"), :<, geometry.dig("title", "left"), message
            assert_in_delta geometry.dig("title", "left"), geometry.dig("actions", "left"), 1, message
            refute geometry.fetch("railVisible"), message
          when "duet"
            assert geometry.fetch("railVisible"), message
            assert_operator geometry.dig("title", "right"), :<=, geometry.dig("rail", "left"), message
            assert_operator geometry.dig("detail", "left"), :>=, geometry.dig("rail", "right"), message
            assert_selector ".record-detail[open]"
          when "unfold"
            assert_operator geometry.dig("heading", "right"), :<, geometry.dig("workspace", "left"), message
            assert_in_delta geometry.dig("title", "left"), geometry.dig("meta", "left"), 1, message
            refute geometry.fetch("railVisible"), message
          end
        end
      end
    end
  end

  test "三主题搜索与收藏完整显示连续长词，窄屏不横向溢出" do
    title = "Reading " + "unbrokenrepositoryname" * 8
    snippet = "Reading " + "unbrokenidentifier" * 8
    @item.update!(title: title, title_zh: nil, summary: snippet, summary_zh: nil)
    users(:drew).favorites.find_by!(url_hash: @item.url_hash).update!(title: title, title_zh: nil, summary: snippet, summary_zh: nil)
    Search::Record.rebuild!

    THEMES.each do |theme|
      [ 320, 375, 768 ].each do |width|
        viewport(width)
        [ search_path(q: "Reading"), favorites_path ].each do |path|
          visit_theme(theme, path)
          assert_selector ".search-title", text: title
          assert_selector ".search-snippet", text: snippet
          assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{theme} #{path} at #{width}px overflows"
          assert evaluate_script(<<~JS), "#{theme} #{path} at #{width}px clips text"
            Array.from(document.querySelectorAll('.search-title, .search-snippet')).every((node) => {
              const range = document.createRange();
              range.selectNodeContents(node);
              const bounds = node.getBoundingClientRect();
              return Array.from(range.getClientRects()).every((rect) => rect.left >= bounds.left - 1 && rect.right <= bounds.right + 1);
            })
          JS
        end
      end
    end
  end

  test "三主题长来源名完整换行，键盘筛选后仍不溢出" do
    name = ("技术资料" * 10 + "unbrokenfeedname" * 4).first(100)
    sources(:hn).update!(name: name)
    THEMES.each do |theme|
      [ 320, 481, 768 ].each do |width|
        viewport(width)
        visit_theme(theme, search_path(q: "Reading"))
        find(".filter-toggle").click if width <= 480
        button = find(".chips button", text: name)
        assert_operator button.native.rect.height, :>=, 44
        assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{theme} #{width}px before selection"
        button.send_keys(:enter)
        assert_selector ".chips button[aria-pressed='true']", text: name
        assert_selector ".chips button[aria-pressed='true']:focus", text: name
        assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{theme} #{width}px after selection"
        assert_operator find(".chips button", text: "GitHub Trending").native.rect.height, :>=, 44
      end
    end
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
    end

    def visit_theme(theme, path)
      execute_script("localStorage.setItem('lowpass-theme', arguments[0])", theme)
      visit path
      assert_selector "html[data-theme='#{theme}']", visible: :all
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
    end
end
