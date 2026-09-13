require "test_helper"

# R-3.6 启停：停用后不再调度，历史条目保留
class Admin::Sources::EnablementsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "停用" do
    delete admin_source_enablement_path(sources(:hackaday))

    assert_redirected_to admin_sources_path
    assert_not sources(:hackaday).reload.enabled
    assert_equal "已停用 Hackaday", flash[:notice]
    assert_equal "source.disable", AuditLog.sole.action
  end

  test "启用" do
    sources(:hackaday).update!(enabled: false)

    post admin_source_enablement_path(sources(:hackaday))

    assert sources(:hackaday).reload.enabled
    assert_equal "已启用 Hackaday", flash[:notice]
    assert_equal "source.enable", AuditLog.sole.action
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    delete admin_source_enablement_path(sources(:hackaday))
    assert_response :forbidden
    assert sources(:hackaday).reload.enabled
  end
end
