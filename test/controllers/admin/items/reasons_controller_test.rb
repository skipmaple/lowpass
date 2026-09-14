require "test_helper"

class Admin::Items::ReasonsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "单条重生成：同步调用一次，成功回日刊页并提示" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。", interest_tag: "AI / LLM"))
      post admin_item_reason_path(items(:hn_one)), headers: { "Referer" => daily_issue_url("2026-09-08") }
    end
    assert_redirected_to daily_issue_url("2026-09-08")
    assert_equal "已重生成", flash[:notice]
    assert_equal "AI / LLM", items(:hn_one).reload.interest_tag
    assert_equal "item.regenerate_reason", AuditLog.sole.action
  end

  test "失败带原因；没配供应商提示未配置；成员 403" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 500, body: "boom")
      post admin_item_reason_path(items(:hn_one))
    end
    assert_redirected_to daily_issue_path("2026-09-08")
    assert_equal "重生成失败：模型服务 500: boom", flash[:alert]

    post admin_item_reason_path(items(:hn_one))
    assert_equal "未配置模型供应商", flash[:alert]

    sign_in_as(users(:guest))
    post admin_item_reason_path(items(:hn_one))
    assert_response :forbidden
  end
end
