require "application_system_test_case"

class ResultReadingLayoutTest < ApplicationSystemTestCase
  setup do
    @item = items(:hn_one)
    @item.update!(title: "Reading measure: a long technical headline that stays with its translated title and explanatory paragraph",
      title_zh: "阅读版心：长标题与译文及摘要保持在同一阅读列中",
      summary: "Reading measure keeps the title, paragraph and associated actions together.")
    Search::Record.rebuild!
    Favorite.keep(users(:drew), @item)
    sign_in_with_browser(users(:drew))
  end

  test "搜索与收藏的文字分隔线与操作共享居中阅读列，书签紧随所在期" do
    [ 1440, 1920 ].each do |width|
      viewport(width)
      [ search_path(q: "Reading measure"), favorites_path ].each do |path|
        visit path
        assert_selector ".search-row .item-translation"
        geometry = evaluate_script(<<~JS)
          (() => {
            const row = document.querySelector('.search-row');
            const rect = (selector) => row.querySelector(selector).getBoundingClientRect();
            const bounds = row.getBoundingClientRect(), sheet = document.querySelector('.sheet-body').getBoundingClientRect();
            const reading = document.querySelector('.search-reading, .results-reading').getBoundingClientRect();
            const where = rect('.search-links > a'), bookmark = rect('.favorite-button');
            return { row: bounds.width, center: bounds.left + bounds.width / 2, sheetCenter: sheet.left + sheet.width / 2,
              reading: reading.width, readingLeft: reading.left, rowLeft: bounds.left,
              title: rect('.search-title').width,
              translation: rect('.item-translation').width, snippet: rect('.search-snippet').width,
              metaTop: rect('.result-meta').top, snippetBottom: rect('.search-snippet').bottom,
              bookmarkGap: bookmark.left - where.right, bookmarkWidth: bookmark.width, bookmarkHeight: bookmark.height,
              whereCenter: where.top + where.height / 2, bookmarkCenter: bookmark.top + bookmark.height / 2 };
          })()
        JS
        assert_in_delta geometry.fetch("translation"), geometry.fetch("title"), 1, "#{path} at #{width}px: #{geometry}"
        assert_in_delta geometry.fetch("translation"), geometry.fetch("snippet"), 1
        assert_in_delta width >= 1920 ? 920 : 780, geometry.fetch("row"), 1
        assert_in_delta geometry.fetch("row"), geometry.fetch("title"), 1
        assert_in_delta geometry.fetch("row"), geometry.fetch("reading"), 1
        assert_in_delta geometry.fetch("rowLeft"), geometry.fetch("readingLeft"), 1
        assert_in_delta geometry.fetch("sheetCenter"), geometry.fetch("center"), 1
        assert_operator geometry.fetch("metaTop"), :>=, geometry.fetch("snippetBottom")
        assert_operator geometry.fetch("bookmarkGap"), :>=, 0
        assert_operator geometry.fetch("bookmarkGap"), :<=, 16, "#{path} at #{width}px: 收藏应与所在期组成紧凑操作组"
        assert_in_delta geometry.fetch("whereCenter"), geometry.fetch("bookmarkCenter"), 1
        assert_operator geometry.fetch("bookmarkWidth"), :>=, 44
        assert_operator geometry.fetch("bookmarkHeight"), :>=, 44
      end
    end
  end

  test "搜索与收藏完整显示连续长词，窄屏不横向溢出" do
    title = "Reading " + "unbrokenrepositoryname" * 8
    snippet = "Reading " + "unbrokenidentifier" * 8
    @item.update!(title: title, summary: snippet)
    users(:drew).favorites.find_by!(url_hash: @item.url_hash).update!(title: title, summary: snippet)
    Search::Record.rebuild!

    [ 320, 375, 768 ].each do |width|
      viewport(width)
      [ search_path(q: "Reading"), favorites_path ].each do |path|
        visit path
        assert_selector ".search-title", text: title
        assert_selector ".search-snippet", text: snippet
        assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{path} at #{width}px overflows"
        assert evaluate_script(<<~JS), "#{path} at #{width}px clips text"
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

  test "长来源名可换行完整显示，键盘筛选后仍不溢出" do
    name = ("技术资料" * 10 + "unbrokenfeedname" * 4).first(100)
    sources(:hn).update!(name: name)
    [ 320, 481, 768 ].each do |width|
      viewport(width)
      visit search_path(q: "Reading")
      find(".filter-toggle").click if width <= 480
      button = find(".chips button", text: name)
      assert_operator button.native.rect.height, :>=, 44
      assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{width}px before selection"
      button.send_keys(:enter)
      assert_selector ".chips button[aria-pressed='true']", text: name
      assert_selector ".chips button[aria-pressed='true']:focus", text: name
      assert evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "#{width}px after selection"
      assert_in_delta 44, find(".chips button", text: "GitHub Trending").native.rect.height, 1
    end
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
    end
end
