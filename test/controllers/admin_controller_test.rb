require "test_helper"

# AC-3.5：非管理员访问 /admin 下任意路径得到 403 页，不跳登录页；未登录先撞登录墙
class AdminControllerTest < ActionDispatch::IntegrationTest
  test "成员访问 /admin/jobs 是 403 页" do
    sign_in_as(users(:guest))

    get "/admin/jobs"

    assert_response :forbidden
    assert_equal "Errors/Forbidden", page_component
    assert_equal "06:00", page_props["daily_time"]
  end

  test "成员访问 /admin 下不存在的路径也是 403" do
    sign_in_as(users(:guest))

    get "/admin/nope"

    assert_response :forbidden
    assert_equal "Errors/Forbidden", page_component
  end

  test "管理员访问 /admin 下不存在的路径是 404" do
    sign_in_as(users(:drew))

    get "/admin/nope"

    assert_response :not_found
    assert_equal "Errors/NotFound", page_component
  end

  # mission_control-jobs 是挂载的引擎（config/routes.rb 的 mount）：Rails 匹配挂载点时把
  # SCRIPT_NAME 吃掉挂载前缀、PATH_INFO 归一成 "/"，require_authentication 在引擎控制器里
  # 算 request.fullpath 时看到的就是这两段拼回去的 "/admin/jobs/"，比原始请求多一个尾斜杠——
  # 不影响回跳：这条路由按前缀匹配，带不带尾斜杠都落回同一个引擎。expected 要在请求前算好：
  # 请求一旦落进这个挂载的引擎，集成测试会话自己的 url_options 也会带上同一段 script_name，
  # 请求之后再调 login_path 会把这段前缀也拼回来
  test "未登录访问 /admin/jobs 先去登录" do
    expected = login_path(next: "/admin/jobs/")

    get "/admin/jobs"

    assert_redirected_to expected
  end

  test "开发环境专用的 /jobs 不再存在" do
    sign_in_as(users(:drew))

    get "/jobs"

    assert_response :not_found
  end
end
