require "application_system_test_case"

# T2：用真实页面、ItemRow 与字体测量标题自身的末行，标签不算标题里的第二个词。
class TitleTailTest < ApplicationSystemTestCase
  [
    [ "Tailwind Labs is joining Shopify", "前端开发" ],
    [ "Hunting the Wild Vibrotruck", "电子机械与自动化" ]
  ].each do |title, tag|
    test "320px 带标签的 #{title} 末行保留至少两个词" do
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
      assert layout.fetch("newsreader_loaded"), "实际 Newsreader face 已加载"
      assert_operator layout.fetch("lines").length, :>, 1, "反例必须确实折行"
      assert_operator layout.fetch("lines").last.split.length, :>=, 2, "实际标题行：#{layout.fetch('lines').inspect}"
      assert layout.fetch("tag_placed"), "标签应紧邻标题末尾或整签换到下一行行首"
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
    assert layout.fetch("tag_placed"), "超长尾词折行后标签仍在标题末尾或下一行行首"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "尾片段保留链接的下划线、原生悬停加深与打印隐藏" do
    item = items(:hn_one)
    item.update!(title: "Tailwind Labs is joining Shopify", interest_tag: "前端开发")
    sign_in_with_browser(users(:drew))
    visit daily_issue_path("2026-09-08")
    assert_selector ".item-title-tail"
    evaluate_async_script("document.fonts.ready.then(arguments[0])")
    states = { "normal" => title_decoration }
    page.save_screenshot(Rails.root.join("tmp/screenshots/title_tail_decoration_normal.png"))

    find(".item-title a").hover
    wait_until { title_decoration.fetch("anchor").fetch("text-decoration-color") == "rgb(29, 29, 27)" }
    states["hover"] = title_decoration
    page.save_screenshot(Rails.root.join("tmp/screenshots/title_tail_decoration_hover.png"))
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    states["print"] = title_decoration
    page.save_screenshot(Rails.root.join("tmp/screenshots/title_tail_decoration_print.png"))

    assert_equal "underline", states.fetch("normal").fetch("anchor").fetch("text-decoration-line")
    assert_equal "none", states.fetch("print").fetch("anchor").fetch("text-decoration-line")
    states.each do |mode, values|
      assert_equal values.fetch("anchor"), values.fetch("tail"), "#{mode}：尾片段应跟随原链接装饰；实际状态 #{states.to_json}"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  private
    def title_decoration
      evaluate_script(<<~JS)
        (() => {
          const anchor = document.querySelector('.item-title a')
          const properties = ['text-decoration-line', 'text-decoration-color', 'text-decoration-thickness', 'text-underline-offset']
          const read = element => Object.fromEntries(properties.map(name => [name, getComputedStyle(element).getPropertyValue(name)]))
          return {anchor:read(anchor), tail:read(anchor.querySelector('.item-title-tail'))}
        })()
      JS
    end

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
          const last = lines.at(-1), tag = article.querySelector('.item-tag').getBoundingClientRect()
          const heading = article.querySelector('.item-heading').getBoundingClientRect()
          const adjacent = Math.abs(tag.bottom - last.bottom) <= 6 && tag.left >= last.right
          const nextLine = tag.top >= last.bottom - 1 && Math.abs(tag.left - heading.left) <= 1
          return {
            text:anchor.textContent, tag:article.querySelector('.item-tag').textContent,
            lines:lines.map(line => line.text.trim()), tag_placed:adjacent || nextLine,
            font_status:document.fonts.status,
            newsreader_loaded:[...document.fonts].some(face => face.family.includes('Newsreader') && face.status === 'loaded'),
            no_overflow:document.documentElement.scrollWidth <= document.documentElement.clientWidth
          }
        })()
      JS
    end
end
