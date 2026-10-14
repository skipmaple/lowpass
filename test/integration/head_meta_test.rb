require "test_helper"

# 设计说明 2026-10-14 D1：每一页的 <head> 都带主题色、简介、manifest 与分享卡片。
# 登录页是唯一对外可见的页面，分享出去的链接都会落到它上面。
class HeadMetaTest < ActionDispatch::IntegrationTest
  TAGLINE = "每天一期技术日刊，登录后阅读".freeze

  test "登录页的 head 带主题色、简介、manifest 与分享卡片" do
    get login_path

    assert_response :success
    assert_select "meta[name=theme-color][content='#1D1D1B']"
    assert_select "meta[name=description][content=?]", TAGLINE
    assert_select "link[rel=manifest][href='/manifest.webmanifest']"
    assert_select "meta[property='og:site_name'][content=Lowpass]"
    assert_select "meta[property='og:description'][content=?]", TAGLINE
    assert_select "meta[property='og:image'][content$='/og.png']"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
  end

  test "manifest 用纸色与墨色，分享图 1200×630 且不超过 150 KB" do
    manifest = JSON.parse(Rails.root.join("public/manifest.webmanifest").read)
    assert_equal "#1D1D1B", manifest["theme_color"]
    assert_equal "#E8E3DA", manifest["background_color"]
    assert_equal "standalone", manifest["display"]
    assert_equal "/", manifest["start_url"]

    png = Rails.root.join("public/og.png")
    assert png.exist?
    assert_operator png.size, :<=, 150.kilobytes
    assert_equal [ 1200, 630 ], png.binread[16, 8].unpack("NN")
  end

  test "正文字体声明 preload 成样式表，不在阻塞渲染的 CSS 里" do
    get login_path

    assert_select "link[rel=preload][as=style][data-content-fonts][href$='.css']"
  end
end
