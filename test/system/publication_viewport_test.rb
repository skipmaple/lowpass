require "application_system_test_case"

class PublicationViewportTest < ApplicationSystemTestCase
  setup { sign_in_with_browser(users(:drew)) }

  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "三主题刊头与导航适应常驻滚动条占用的宽度" do
    %w[ daybreak duet unfold ].each do |theme|
      [ 320, 375, 1440, 1920 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
        execute_script("localStorage.setItem('lowpass-theme', arguments[0])", theme)
        [ daily_issue_path("2026-09-08"), favorites_path, search_path ].each do |path|
          visit path
          assert_selector "html[data-theme='#{theme}']", visible: :all
          evaluate_async_script("document.fonts.ready.then(arguments[0])")
          # Overlay-scrollbar platforms also exercise the 15px reserved by Linux/Windows.
          execute_script("document.documentElement.style.width = `${innerWidth - 15}px`")
          geometry = evaluate_script(<<~JS)
            (() => {
              const root = document.documentElement, edge = root.getBoundingClientRect().right;
              const nodes = [...document.querySelectorAll('.publication-mast, .publication-context, .masthead, .masthead-nav, .masthead-actions, .primary-nav-link, .page-head')];
              return { edge, rootWidth: root.clientWidth, rootScrollWidth: root.scrollWidth,
                boxes: nodes.filter(node => node.getBoundingClientRect().width > 1).map(node => {
                  const rect = node.getBoundingClientRect();
                  return { name: node.className, left: rect.left, right: rect.right };
                }),
                sheetWidth: document.querySelector(".sheet").clientWidth, sheetScrollWidth: document.querySelector(".sheet").scrollWidth,
                mastheadWidth: document.querySelector('.masthead').clientWidth,
                mastheadScrollWidth: document.querySelector('.masthead').scrollWidth };
            })()
          JS
          context = "#{theme} #{width}px #{path}: #{geometry}"
          geometry.fetch("boxes").each do |box|
            assert_operator box.fetch("left"), :>=, -0.5, context
            assert_operator box.fetch("right"), :<=, geometry.fetch("edge") + 0.5, context
          end
          assert_operator geometry.fetch("rootScrollWidth"), :<=, geometry.fetch("rootWidth"), context
          assert_operator geometry.fetch("sheetScrollWidth"), :<=, geometry.fetch("sheetWidth"), context
          assert_operator geometry.fetch("mastheadScrollWidth"), :<=, geometry.fetch("mastheadWidth"), context
        end
      end
    end
  end
end
