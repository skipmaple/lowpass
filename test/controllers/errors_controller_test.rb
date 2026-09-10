require "test_helper"

# 兜底路由（config/routes.rb 末尾的 match "*path"）本身的行为；具体页面挂的 404
# （非法周期键、越界月份/年份）分别在各自的 controller test 里。
class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "站内没有的地址渲染附录 B 的 404 页" do
    get "/no-such-page"

    assert_response :not_found
    assert_equal "Errors/NotFound", page_component
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
end
