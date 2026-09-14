require "test_helper"

class Reasons::GeneratorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @issue = issues(:daily_0908)
    @item = items(:hn_one)
    @other = Item.create!(source: sources(:github), issue: @issue, title: "octo/tool", url: "https://github.com/octo/tool", url_hash: Digest::SHA256.hexdigest("https://github.com/octo/tool"), rank: 1, fetched_at: Time.current, meta: { "stars" => 10, "language" => "Go" })
  end

  test "没配供应商：什么都不做，也不记账" do
    outcome = Reasons::Generator.generate!(@issue)
    assert outcome.skipped
    assert_equal 0, ModelCall.count
    assert_nil @item.reload.reason
  end

  test "一期全部生成：理由、标签、时间与账本；跑完收掉缺理由事件" do
    open = alert_event(kind: "reasons_missing", source: nil, issue: @issue, dedup_key: "rm")
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。", interest_tag: "AI / LLM", prompt_tokens: 100, completion_tokens: 40))
      outcome = Reasons::Generator.generate!(@issue)
      assert_equal [ 2, 0, 0, false ], [ outcome.generated, outcome.reused, outcome.failed, outcome.skipped ]
    end
    @item.reload
    assert_equal "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。", @item.reason
    assert_equal "AI / LLM", @item.interest_tag
    assert_not_nil @item.reason_generated_at
    assert_equal 2, ModelCall.where(status: "ok", issue: @issue).count
    assert_equal BigDecimal("0.0005"), ModelCall.first.cost
    assert_not_nil open.reload.recovered_at
  end

  test "输出缺领域名：重试 2 次后留空，账本记 invalid" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "一" * 30, interest_tag: "不存在"))
      assert_not Reasons::Generator.generate_item!(@item)
    end
    assert_nil @item.reload.reason
    assert_equal 3, ModelCall.where(item: @item, status: "invalid").count
    assert_equal "缺领域名", ModelCall.last.error_summary
  end

  test "超时记 timed_out 并重试；密钥被拒绝整期停止" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_timeout
      assert_not Reasons::Generator.generate_item!(@item)
      assert_equal 3, ModelCall.where(item: @item, status: "timed_out").count

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 401)
      outcome = Reasons::Generator.generate!(@issue)
      assert_equal 1, outcome.failed
      assert_equal 1, ModelCall.where(status: "failed", error_summary: "密钥被拒绝").count   # 第一条就停，第二条没调
    end
  end

  test "月上限到了：不调模型，告警一次" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      with_model_provider do
        Setting.set("model_monthly_cap", "1")
        ModelCall.create!(status: "ok", cost: 1)
        assert_no_difference("ModelCall.count") { Reasons::Generator.generate!(@issue) }
      end
    end
    event = AlertEvent.find_by!(kind: "reasons_missing")
    assert_equal "本月费用已达上限，缺理由 2 条", event.summary
    assert_equal @issue, event.issue
  end

  test "only_missing 只补空的；整期重生成覆盖旧理由" do
    @item.update!(reason: "旧理由", interest_tag: "AI / LLM", reason_generated_at: 1.day.ago)
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发"))
      assert_equal 1, Reasons::Generator.generate!(@issue).generated
      assert_equal "旧理由", @item.reload.reason
      assert_equal 2, Reasons::Generator.generate!(@issue, only_missing: false).generated
      assert_equal "前端开发", @item.reload.interest_tag
    end
  end

  test "跨天重复的条目沿用前一期的理由，不调模型（R-1.11）" do
    @item.update!(reason: "前一天的理由，二十个字以上的中文句子，用来复用。", interest_tag: "AI / LLM", reason_generated_at: 1.day.ago)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", published_at: Time.current, generation_started_at: Time.current)
    dup = Item.create!(source: sources(:hn), issue: later, title: @item.title, url: @item.url, url_hash: @item.url_hash, rank: 1, fetched_at: Time.current)
    with_model_provider do
      outcome = Reasons::Generator.generate!(later)
      assert_equal [ 0, 1 ], [ outcome.generated, outcome.reused ]
    end
    assert_equal @item.reason, dup.reload.reason
    assert_equal "AI / LLM", dup.interest_tag
    assert_equal 0, ModelCall.count
  end
end
