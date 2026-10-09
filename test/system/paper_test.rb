require "application_system_test_case"
require "base64"

class PaperTest < ApplicationSystemTestCase
  test "纸色与纹理不随刊物长度或滚动位置变化" do
    css = Rails.root.join("app/frontend/styles/tokens.css").read
    html = "<style>#{css} html { scrollbar-width: none; }</style><div class='paper' style='height:1800px'></div>"
    # 直接渲染生产 CSS，排除正文与图片；比较同一视口的实际像素，而不是样式声明。
    visit "data:text/html;base64,#{Base64.strict_encode64(html)}"
    short = page.driver.browser.screenshot_as(:png)

    execute_script "document.querySelector('.paper').style.height = '50000px'"
    assert short == page.driver.browser.screenshot_as(:png), "长周刊的纸面应与短日刊一致"

    execute_script "window.scrollTo(0, 600)"
    wait_until { evaluate_script("window.scrollY") == 600 }
    assert short == page.driver.browser.screenshot_as(:png), "滚动后应保持相同的纸纹周期"
  end
end
