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

  # 供应商配好了但画像是空的：调了也是每条判「缺领域名」，白花钱（终审 F1）
  test "画像为空：提示兴趣画像为空，不调模型" do
    with_model_provider do
      InterestArea.update_all(enabled: false)
      assert_no_difference("ModelCall.count") { post admin_item_reason_path(items(:hn_one)) }
    end
    assert_redirected_to daily_issue_path("2026-09-08")
    assert_equal "兴趣画像为空", flash[:alert]
  end

  # 单条这条路也走模型，月上限一样要拦（设计 §10 的文案，终审 F2）
  test "月上限到了：提示已停止生成，不调模型" do
    ModelCall.create!(status: "ok", cost: 1)
    with_model_provider do
      Setting.set("model_monthly_cap", "1")
      assert_no_difference("ModelCall.count") { post admin_item_reason_path(items(:hn_one)) }
    end
    assert_equal "本月费用已达上限，已停止生成", flash[:alert]
  end

  # D19 周刊条目没有理由，也就没有这个端点
  test "周刊条目 404" do
    weekly_item = Item.create!(source: sources(:ruanyf), issue: issues(:weekly_w36), title: "本周的一条", url: "https://ruanyf.example/1",
                               url_hash: Digest::SHA256.hexdigest("https://ruanyf.example/1"), rank: 1, fetched_at: Time.current)
    with_model_provider { post admin_item_reason_path(weekly_item) }
    assert_response :not_found
  end
end
