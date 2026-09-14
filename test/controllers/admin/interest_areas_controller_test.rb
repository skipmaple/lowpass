require "test_helper"

class Admin::InterestAreasControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "新增、修改、停用、删除，都记审计" do
    post admin_interest_areas_path, params: { interest_area: { name: "Rust", keywords: "所有权、异步、嵌入式" } }
    assert_redirected_to admin_settings_path
    assert_equal "已保存 Rust", flash[:notice]
    area = InterestArea.find_by!(name: "Rust")
    assert_equal 8, area.sort_order   # 排在最后（fixture 里最大排序值 7 + 1）
    assert_equal "interest_area.create", AuditLog.last.action

    patch admin_interest_area_path(area), params: { interest_area: { name: "Rust", keywords: "所有权", sort_order: 1, enabled: false } }
    assert_redirected_to admin_settings_path
    area.reload
    assert_equal [ "所有权", 1, false ], [ area.keywords, area.sort_order, area.enabled ]
    assert_equal "interest_area.update", AuditLog.last.action

    delete admin_interest_area_path(area)
    assert_redirected_to admin_settings_path
    assert_equal "已删除 Rust", flash[:notice]
    assert_nil InterestArea.find_by(name: "Rust")
    assert_equal "interest_area.destroy", AuditLog.last.action
  end

  test "校验失败回设置页带句子" do
    post admin_interest_areas_path, params: { interest_area: { name: "ai / llm", keywords: "" } }
    assert_redirected_to admin_settings_path
    assert_equal "名称已存在", flash[:alert]

    post admin_interest_areas_path, params: { interest_area: { name: "", keywords: "k" * 201 } }
    assert_equal "必填 · 最多 200 字", flash[:alert]
  end

  test "成员 403" do
    sign_in_as(users(:guest))
    post admin_interest_areas_path, params: { interest_area: { name: "x" } }
    assert_response :forbidden
  end
end
