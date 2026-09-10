require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "root renders the Home Inertia page" do
    get root_path

    assert_response :success
    # inertia_rails 的 use_script_element_for_initial_page 把 payload 渲染成
    # <script data-page="app" type="application/json">{"component":"Home",...}</script>——
    # data-page 只是元素 id（固定值 "app"），真正的 JSON 是 script 的文本内容、没有被 HTML 转义
    # （page.to_json.html_safe），所以引号是原样的 "，不是 &quot;。一条正则同时锚定这个
    # script 标签与它内容里的 component 字段，比两条独立的 assert_includes 更能确认
    # 「Home」确实是 Inertia payload 的 component 而不是页面别处偶然出现的字符串。
    assert_match(/<script data-page="app"[^>]*>[^<]*"component":"Home"/, response.body)
  end
end
