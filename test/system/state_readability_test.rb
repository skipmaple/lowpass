require "application_system_test_case"

class StateReadabilityTest < ApplicationSystemTestCase
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "日刊空刊的完整事实句在手机末行不只剩一个字" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    sign_in_with_browser(users(:drew))

    assert_notice_lines(daily_issue_path("2026-09-07"), "本期为空刊，管理员已收到通知")
  end

  test "周刊降级的事实句不留孤字且保留原文操作" do
    issue = Issue.create!(kind: "weekly", period_key: "2026-W37", state: "published", generation_started_at: Time.utc(2026, 9, 11, 1), published_at: Time.utc(2026, 9, 11, 1, 5), source_states: { sources(:ruanyf).id => "ok" })
    url = "https://github.com/ruanyf/weekly/blob/master/docs/issue-367.md"
    issue.items.create!(source: sources(:ruanyf), title: "科技爱好者周刊（第 367 期）：原文", url: url, url_hash: Digest::SHA256.hexdigest(url), fetched_at: Time.current, meta: { issue_no: 367, issue_title: "原文", degraded: true })
    sign_in_with_browser(users(:drew))

    assert_notice_lines(weekly_issue_path("2026-W37"), "本期解析失败，已保留原文链接")
    assert_selector ".source-foot[href='#{url}'][target='_blank']", text: "科技爱好者周刊（第 367 期）：原文"
  end

  test "未配置时两处部署帮助保持文字字号并有真实44px点击区" do
    with_alert_channels do
      with_backup_config({}) do
        sign_in_with_browser(users(:drew))
        [ 320, 375, 768, 1440 ].each do |width|
          viewport(width)
          visit admin_settings_path
          assert_selector ".admin-actions a[href='#deployment']", count: 2
          evaluate_async_script("const done=arguments[0];document.fonts.ready.then(()=>requestAnimationFrame(()=>requestAnimationFrame(done)))")
          [ "alerts", "backup" ].each do |section|
            selector = "##{section} .admin-actions a[href='#deployment']"
            link = find(selector)
            assert_equal "查看部署配置帮助", link.text
            assert_operator link.native.rect.height, :>=, 44, "#{width}px #{section}：实际目标高度"
            assert_equal "13px", evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).fontSize")
            execute_script("document.querySelector(#{selector.to_json}).scrollIntoView({block:'center'})")
            note_hits = evaluate_script(<<~JS)
              (() => {
                const link = document.querySelector(#{selector.to_json}), note = link.closest('.admin-actions').querySelector('span.field-note')
                const walker = document.createTreeWalker(note, NodeFilter.SHOW_TEXT), hits = []
                for (let node; (node = walker.nextNode());) {
                  if (node.parentElement.closest('a')) continue
                  const range = document.createRange(); range.selectNodeContents(node)
                  for (const r of range.getClientRects()) for (let x=Math.floor(r.left)+.5;x<r.right;x++) for (let y=Math.floor(r.top)+.5;y<r.bottom;y++) {
                    if (x >= r.left && y >= r.top && document.elementFromPoint(x,y)?.closest('a')===link) hits.push({x,y})
                  }
                }
                return hits
              })()
            JS
            assert_empty note_hits, "#{width}px #{section}：说明文字不能命中帮助链接"
            points = evaluate_script(<<~JS)
              (() => {
                const link = document.querySelector(#{selector.to_json}), r = link.getBoundingClientRect()
                return [r.left + 1, r.left + r.width / 2, r.right - 1].flatMap(x => [r.top + 1, r.top + r.height / 2, r.bottom - 1].map(y => ({x:Math.round(x), y:Math.round(y)})))
              })()
            JS
            points.each do |point|
              execute_script("document.querySelector(#{selector.to_json}).scrollIntoView({block:'center'})")
              execute_script(<<~JS)
                window.lastHelpClick = null
                document.addEventListener('click', event => { window.lastHelpClick = {trusted:event.isTrusted, href:event.target.closest('a')?.getAttribute('href')} }, {once:true})
              JS
              page.driver.browser.action.move_to_location(point.fetch("x"), point.fetch("y"), duration: 0).click.perform
              assert_equal({ "trusted" => true, "href" => "#deployment" }, evaluate_script("window.lastHelpClick"), "#{width}px #{section}：原生点击 #{point.inspect}")
              wait_for_deployment_anchor
            end
            link.send_keys(:enter)
            assert_equal "#deployment", evaluate_script("location.hash")
            wait_for_deployment_anchor
            page.driver.browser.switch_to.active_element.send_keys(:tab)
            assert evaluate_script("document.activeElement.matches('#deployment summary')"), "#{width}px #{section}：下一Tab到部署帮助"
            assert_selector "##{section} .admin-actions button[disabled]"
            assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
          end
        end
      end
    end
  end

  private
    def viewport(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
    end

    # 原生hash会让Inertia异步恢复锚点；等它落定后才返回原链接采样下一点。
    def wait_for_deployment_anchor
      evaluate_async_script("const done=arguments[0];requestAnimationFrame(()=>setTimeout(()=>requestAnimationFrame(done)))")
      wait_until do
        evaluate_script(<<~JS)
          (() => {
            const target = document.getElementById('deployment')
            const wanted = target.getBoundingClientRect().top + scrollY - parseFloat(getComputedStyle(target).scrollMarginTop)
            const maximum = document.documentElement.scrollHeight - innerHeight
            return Math.abs(scrollY - Math.max(0, Math.min(wanted, maximum))) < 2
          })()
        JS
      end
    end

    def assert_notice_lines(path, text)
      [ 320, 375, 1440 ].each do |width|
        viewport(width)
        visit path
        assert_selector ".state-line", text: text, exact_text: true
        evaluate_async_script("const done=arguments[0];document.fonts.ready.then(()=>requestAnimationFrame(()=>requestAnimationFrame(done)))")
        lines = evaluate_script(<<~JS)
          (() => {
            const node = document.querySelector('.state-line').firstChild, lines = []
            let offset = 0
            for (const char of node.textContent) {
              const range = document.createRange(); range.setStart(node, offset); range.setEnd(node, offset + char.length); offset += char.length
              const box = range.getBoundingClientRect(), line = lines.find(line => Math.abs(line.top - box.top) < 1)
              if (line) line.text += char
              else lines.push({top:box.top, text:char})
            }
            return lines.map(line => line.text)
          })()
        JS
        assert_equal text, lines.join, "#{width}px：完整原文"
        assert_operator lines.last.scan(/\p{Han}/).length, :>, 1, "#{width}px：末行不只剩一字：#{lines.inspect}"
        assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, width
      end
    end
end
