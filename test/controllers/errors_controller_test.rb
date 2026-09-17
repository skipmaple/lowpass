require "test_helper"

# 兜底路由（config/routes.rb 末尾的 match "*path"）本身的行为；具体页面挂的 404
# （非法周期键、越界月份/年份）分别在各自的 controller test 里。
class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "站内没有的地址渲染附录 B 的 404 页" do
    sign_in_as(users(:drew))

    get "/no-such-page"

    assert_response :not_found
    assert_equal "Errors/NotFound", page_component
  end

  # 设计 L4：兜底 404 也在登录墙内，没登录先去登录
  test "没登录时不存在的地址也先去登录" do
    get "/no-such-page"

    assert_redirected_to login_path(next: "/no-such-page")
  end

  # 兜底路由只接 GET（HEAD 由 Rack::Head 折算成 GET）：非 GET 方法没有路由可落，落到
  # ActionController::RoutingError。test 环境 show_exceptions 是 :rescuable，RoutingError
  # 在默认的 rescue_responses 里映射到 404，所以还是渲染 404（走 config.exceptions_app，
  # 不是 errors#not_found 那个 Inertia 页）。这样非 GET 请求不会先撞见 CSRF 校验，把 404
  # 变成 422（未带合法 authenticity token 时 InvalidAuthenticityToken 才是 422）。
  test "兜底路由只接 GET，非 GET 方法没有路由可落" do
    routes = Rails.application.routes

    assert_equal "errors", routes.recognize_path("/nope", method: :get)[:controller]
    assert_raises(ActionController::RoutingError) { routes.recognize_path("/nope", method: :post) }
  end

  test "没有路由的写请求使用中文静态 404 恢复页" do
    without_detailed_exceptions { post "/no-such-route" }

    assert_response :not_found
    assert_select "html[lang='zh-CN']"
    assert_select "h1", text: "找不到这个页面"
    assert_select "nav[aria-label='恢复操作'] a[href='/']", text: "回到首页"
  end

  test "CSRF 拒绝后的静态 422 不提供重新提交入口" do
    previous_protection = ApplicationController.allow_forgery_protection
    sign_in_as(users(:drew))
    ApplicationController.allow_forgery_protection = true

    assert_no_difference -> { Source.count } do
      without_detailed_exceptions { post admin_sources_path, params: { source: { name: "Rejected source" } } }
    end

    assert_response :unprocessable_content
    assert_select "h1", text: "请求未被接受"
    assert_select "nav[aria-label='恢复操作'] a[href='/']", text: "回到首页"
    assert_select "form, button, script, [onclick], meta[http-equiv='refresh']", count: 0
  ensure
    ApplicationController.allow_forgery_protection = previous_protection
  end

  test "旧浏览器被实际拦截时使用中文静态 406" do
    get login_path, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36" }

    assert_response :not_acceptable
    assert_select "h1", text: "浏览器版本过旧"
    assert_select "nav[aria-label='恢复操作'] a[href='/']", text: "回到首页"
  end

  private
    def without_detailed_exceptions
      previous = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
      Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
      yield
    ensure
      Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = previous
    end
end
