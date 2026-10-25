require "application_system_test_case"

class IndependentTranslationsTest < ApplicationSystemTestCase
  test "后台重评确认键盘焦点CSRF与排队反馈，手机布局沿用同一入口" do
    item = items(:hn_one)
    item.store_translation(Translations::Parser::Result.new(decision: "unchanged", text: nil), target: item.translation_target, assessed_at: Time.current)
    item.record_reason_abstention(assessed_at: Time.current)
    InterestArea.update_all(enabled: false)
    with_model_provider do
      sign_in_with_browser(users(:drew))
      with_forgery_protection do
        visit admin_issues_path(month: "2026-09")
        [ [ 1400, "desktop" ], [ 375, "mobile" ] ].each do |width, label|
          page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
          assert_equal width, page.evaluate_script("window.innerWidth")
          row = find('[data-table-row-key="daily-2026-09-08"]')
          opener = row.find_button("补齐译文")
          opener.click
          dialog = find('[role="dialog"]')
          assert_unchecked_field "重新评估保留原文的条目"
          assert_button "提交补全", disabled: true
          assert_text "本次处理 0 条"
          assert_equal "取消", page.evaluate_script("document.activeElement.textContent")
          dialog.check "重新评估保留原文的条目"
          assert_button "提交补全", disabled: false
          dialog.find("input").send_keys(:tab)
          assert_equal "取消", page.evaluate_script("document.activeElement.textContent")
          page.driver.browser.switch_to.active_element.send_keys(:tab)
          assert_equal "提交补全", page.evaluate_script("document.activeElement.textContent")
          page.driver.browser.switch_to.active_element.send_keys(:tab)
          assert_equal "checkbox", page.evaluate_script("document.activeElement.type")
          assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
          assert dialog.evaluate_script("this.getBoundingClientRect().right <= window.innerWidth")
          save_screenshot(Rails.root.join(".superpowers/sdd/2026-10-25-independent-translations/translation-dialog-#{label}.png"))
          page.driver.browser.switch_to.active_element.send_keys(:escape)
          assert_no_selector '[role="dialog"]'
          assert_equal "translations", page.evaluate_script("document.activeElement.dataset.tableFocus")
        end
        find('[data-table-row-key="daily-2026-09-08"]').click_on "补齐译文"
        within('[role="dialog"]') do
          check "重新评估保留原文的条目"
          assert_button "提交补全", disabled: false
          click_on "提交补全"
        end
        assert_text "已提交译文补全任务，刷新查看结果"
        assert_equal "issue.complete_translations", AuditLog.sole.action
        assert_equal 1, AuditLog.sole.payload.fetch("target_count")
        assert_nil item.reload.title_zh
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "没有理由也独立显示中文译文" do
    item = items(:hn_one)
    item.update!(title_zh: "独立补齐的中文标题", reason: nil)
    sign_in_with_browser(users(:drew))
    visit daily_issue_path(item.issue.period_key)
    assert_text "独立补齐的中文标题"
    assert_nil item.reload.reason
  end
end
