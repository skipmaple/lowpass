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

  # R-10.8、AC-10.6：收藏只有本人可见，后台的用户页不带任何收藏信息
  test "用户列表不带收藏信息" do
    Favorite.keep(users(:guest), items(:hn_one))
    sign_in_as(users(:drew))

    get admin_users_path

    assert_equal %w[ display_name email id last_login_label providers_label role ], page_props["users"].first.keys.sort
    assert_not_includes response.body, items(:hn_one).url
  end
end
