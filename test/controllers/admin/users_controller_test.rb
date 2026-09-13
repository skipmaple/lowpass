require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "只读列表" do
    sign_in_as(users(:drew))

    get admin_users_path

    assert_equal "Admin/Users/Index", page_component
    assert_equal 3, page_props["users"].size
    assert_equal "3 个用户 · 只读", page_props["summary"]
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    get admin_users_path
    assert_response :forbidden
  end
end
