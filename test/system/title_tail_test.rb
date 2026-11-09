require "application_system_test_case"

# T2：真实页面的长标题与标签分别排版，完整原文和可操作范围不随主题丢失。
class TitleTailTest < ApplicationSystemTestCase
  [
    [ "Tailwind Labs is joining Shopify", "前端开发" ],
    [ "Hunting the Wild Vibrotruck", "电子机械与自动化" ]
  ].each do |title, tag|
    test "320px 带标签的 #{title} 完整换行且标签保留在元信息中" do
      item = items(:hn_one)
      item.update!(title: title, interest_tag: tag)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 1000, deviceScaleFactor: 1, mobile: false)
      sign_in_with_browser(users(:drew))
      visit daily_issue_path("2026-09-08")
      assert_selector "#item-#{item.id} .item-title a", text: title
      evaluate_async_script("document.fonts.ready.then(arguments[0])")

      layout = title_layout(item)
      assert_equal title, layout.fetch("text")
      assert_equal tag, layout.fetch("tag")
      assert_equal "loaded", layout.fetch("font_status")
      assert layout.fetch("theme_font_loaded"), "当前主题的实际英文字体已加载"
      assert_operator layout.fetch("lines").length, :>, 1, "反例必须确实折行"
      assert layout.fetch("tag_placed"), "标签应留在元信息中，不混入标题链接"
      assert layout.fetch("no_overflow"), "320px 页面不横向溢出"
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
  end

  test "320px 超长尾词保持原文并在正文宽度内折行" do
    title = "A #{'W' * 130} #{'M' * 130}"
    item = items(:hn_one)
    item.update!(title: title, interest_tag: "前端开发")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 1000, deviceScaleFactor: 1, mobile: false)
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    assert_selector "#item-#{item.id} .item-title a", text: title
    evaluate_async_script("document.fonts.ready.then(arguments[0])")

    layout = title_layout(item)
    assert_equal title, layout.fetch("text")
    assert_operator layout.fetch("lines").length, :>, 2
    assert layout.fetch("no_overflow"), "尾两词放不进一行时仍不能横向溢出"
    assert layout.fetch("tag_placed"), "超长尾词折行后标签仍在独立元信息中"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "完整标题保留原生悬停下划线与打印隐藏" do
    item = items(:hn_one)
    item.update!(title: "Tailwind Labs is joining Shopify", interest_tag: "前端开发")
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    title = find("#item-#{item.id} .item-title a")
    assert_equal item.title, title.text
    title.hover
    wait_until { title.evaluate_script("getComputedStyle(this).textDecorationLine") == "underline" }
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_equal "none", title.evaluate_script("getComputedStyle(this).textDecorationLine")
    assert_equal item.url, title[:href]
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  private
    def title_layout(item)
      evaluate_script(<<~JS)
        (() => {
          const article = document.getElementById(#{"item-#{item.id}".to_json})
          const anchor = article.querySelector('.item-title a'), walker = document.createTreeWalker(anchor, NodeFilter.SHOW_TEXT)
          const lines = []
          // 逐字符 Range 只读实际文字盒；不是读取 balance 声明后推测断行。
          for (let node; (node = walker.nextNode());) {
            for (let index = 0; index < node.length; index++) {
              const range = document.createRange(); range.setStart(node, index); range.setEnd(node, index + 1)
              const rect = range.getBoundingClientRect()
              if (!rect.width || !rect.height) continue
              const center = rect.top + rect.height / 2
              let line = lines.find(line => Math.abs(line.center - center) < 2)
              if (!line) lines.push(line = {text:'', center, left:rect.left, right:rect.right, top:rect.top, bottom:rect.bottom})
              line.text += node.textContent[index]
              line.left = Math.min(line.left, rect.left); line.right = Math.max(line.right, rect.right)
              line.top = Math.min(line.top, rect.top); line.bottom = Math.max(line.bottom, rect.bottom)
            }
          }
          return {
            text:anchor.textContent, tag:article.querySelector('.item-tag').textContent,
            lines:lines.map(line => line.text.trim()), tag_placed:article.querySelector('.item-context').contains(article.querySelector('.item-tag')) && !anchor.contains(article.querySelector('.item-tag')),
            font_status:document.fonts.status,
            theme_font_loaded:[...document.fonts].some(face => face.family.includes('Lowpass Latin') && face.status === 'loaded'),
            no_overflow:document.documentElement.scrollWidth <= document.documentElement.clientWidth
          }
        })()
      JS
    end
end
