require "test_helper"

class Translations::GeneratorTest < ActiveSupport::TestCase
  setup do
    @item = items(:hn_one)
    @issue = @item.issue
    @item.update!(title: "Steal My Bitcoin")
  end

  test "理由为空或合法拒写和画像为空都不阻挡独立译文" do
    InterestArea.update_all(enabled: false)
    @item.record_reason_abstention(assessed_at: Time.current)
    original = @item.attributes.except("title_zh", "updated_at")
    issue_before = @issue.attributes
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply(text: "偷走我的比特币"))
      outcome = generate
      assert_equal 1, outcome.translated
      assert_requested stub, times: 1
    end
    assert_equal "偷走我的比特币", @item.reload.title_zh
    assert_equal original, @item.attributes.except("title_zh", "updated_at")
    assert_equal issue_before, @issue.reload.attributes
    assert @item.reason_abstention
    assert_equal [ [ "translation", "title", "ok" ] ], ModelCall.pluck(:purpose, :input_field, :status)
  end

  test "已有译文或合法保留原文终态不再收费，显式重评失败保留旧标记" do
    operation = ModelRequests.operation
    targets = [ @item.translation_target ]
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply(decision: "unchanged"))
      assert_equal 1, generate(operation: operation, targets: targets).preserved
      assert_equal 1, generate(operation: operation, targets: targets).skipped
      assert_equal 1, generate(targets: targets).skipped
      assert_requested stub, times: 1
      before = TranslationPreservation.sole.attributes
      WebMock.reset!
      failed = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 500, body: "error")
      assert_equal 1, generate(targets: targets, reassess: true).failed
      assert_equal before, TranslationPreservation.sole.attributes
      assert_requested failed, times: 3
      @item.update!(title_zh: "已有译文")
      assert_equal 1, generate(targets: targets, reassess: true).skipped
      assert_requested failed, times: 3
    end
  end

  test "invalid后成功不采纳失败回复，usage照实记账" do
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(
        { status: 200, body: reply(text: "失败响应的译文", reason: "额外字段") },
        { status: 200, body: reply(text: "成功译文") })
      assert_equal 1, generate.translated
      assert_equal "成功译文", @item.reload.title_zh
      assert_equal [ [ "invalid", BigDecimal("0.0005") ], [ "ok", BigDecimal("0.0005") ] ], ModelCall.order(:id).pluck(:status, :cost)
      assert_requested stub, times: 2
    end
  end

  test "同操作失败最多三次，超时后可成功" do
    operation = ModelRequests.operation
    targets = [ @item.translation_target ]
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: "{\"choices\":[{\"message\":{\"content\":\"not json\"}}]}")
      2.times { assert_equal 1, generate(operation: operation, targets: targets).failed }
      assert_requested stub, times: 3
      assert_nil @item.reload.title_zh
      WebMock.reset!
      timeout = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_timeout.then.to_return(status: 200, body: reply(text: "超时后成功的译文"))
      assert_equal 1, generate(targets: targets).translated
      assert_requested timeout, times: 2
      assert_equal [ "timed_out", "ok" ], ModelCall.order(:id).last(2).map(&:status)
    end
  end

  test "429和预算停止整个操作且不能重放绕过" do
    targets = [ @item.translation_target ]
    operation = ModelRequests.operation
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 429)
      2.times { assert_equal "limited", generate(operation: operation, targets: targets).stop_reason }
      assert_requested stub, times: 1
      WebMock.reset!
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      Setting.set("model_monthly_cap", "0.0005")
      invalid = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply(text: "English only"))
      operation = ModelRequests.operation
      assert_equal "budget", generate(operation: operation, targets: targets).stop_reason
      Setting.set("model_monthly_cap", "0")
      assert_equal "budget", generate(operation: operation, targets: targets).stop_reason
      assert_requested invalid, times: 1
    end
  end

  test "跨日复用译文不要求旧理由且不修改旧期" do
    old_issue = Issue.create!(kind: "daily", period_key: "2026-09-07", state: "published", published_at: 1.day.ago, generation_started_at: 1.day.ago)
    previous = Item.create!(@item.attributes.except("id", "issue_id").merge("issue" => old_issue, "title_zh" => "昨天的合规译文"))
    previous.record_reason_abstention(assessed_at: Time.current)
    before = previous.reload.attributes
    with_model_provider do
      assert_equal 1, generate.reused
      assert_equal 0, ModelCall.count
    end
    assert_equal "昨天的合规译文", @item.reload.title_zh
    assert_equal before, previous.reload.attributes
  end

  test "只按冻结期和指纹请求，不接受调用前改变的目标或其他期条目" do
    targets = [ @item.translation_target ]
    @item.update!(title: "Changed English title")
    with_model_provider do
      assert_equal 1, generate(targets: targets).skipped
      assert_equal 0, ModelCall.count
    end
  end

  test "请求期间删除条目仍留账且不把输出写给替换行" do
    target = @item.translation_target
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
        @item.delete
        { status: 200, body: reply(text: "不能写给新条目的译文") }
      end
      assert_equal 1, generate(targets: [ target ]).skipped
      assert_nil ModelCall.sole.item_id
      assert_equal "translation", ModelCall.sole.purpose
      assert_requested stub, times: 1
    end
  end

  test "保存失败上抛并记账，重放成功调用也不再收费" do
    operation = ModelRequests.operation
    targets = [ @item.translation_target ]
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply(text: "无法保存的译文"))
      Item.any_instance.stubs(:store_translation).raises(ActiveRecord::StatementInvalid, "write failed")
      assert_raises(ActiveRecord::StatementInvalid) { generate(operation: operation, targets: targets) }
      Item.any_instance.unstub(:store_translation)
      assert_equal 1, generate(operation: operation, targets: targets).skipped
      assert_requested stub, times: 1
      assert_equal [ "ok" ], ModelCall.pluck(:status)
      assert_nil @item.reload.title_zh
    end
  ensure
    Item.any_instance.unstub(:store_translation)
  end

  test "请求期间原文隐藏或源配置改变时只留账不落旧译文" do
    mutations = [ -> { @item.update!(title: "Changed during request") },
      -> { @item.update!(hidden: true) }, -> { @item.source.update!(adapter: "rss", config: { feed_url: "https://example.com/feed" }) } ]
    mutations.each do |mutate|
      @item.update!(title: "Steal My Bitcoin", hidden: false)
      @item.source.update!(adapter: "hacker_news")
      target = @item.reload.translation_target
      with_model_provider do
        WebMock.reset!
        stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
          mutate.call
          { status: 200, body: reply(text: "旧输入的译文") }
        end
        assert_equal 1, generate(targets: [ target ]).skipped
        assert_nil @item.reload.title_zh
        assert_requested stub, times: 1
      end
    end
    assert_equal 3, ModelCall.count
  end

  test "源重抓换id不会扩大冻结集合" do
    target = @item.translation_target
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
        attributes = @item.attributes.except("id")
        @item.destroy!
        @replacement = Item.create!(attributes)
        { status: 200, body: reply(text: "只属于旧行的译文") }
      end
      assert_equal 1, generate(targets: [ target ]).skipped
      assert_nil @replacement.reload.title_zh
      assert_requested stub, times: 1
    end
  end

  test "GitHub只译非空英文简介且不改项目名或已有理由" do
    @item.update!(source: sources(:github), title: "owner/Project", summary: "A small useful project", reason: "已有推荐理由", interest_tag: "后端开发")
    before = @item.attributes.except("summary_zh", "updated_at")
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).with { |request|
        payload = JSON.parse(request.body)
        assert_equal 600, payload["max_tokens"]
        JSON.parse(payload["messages"].last["content"]) == { "field" => "summary", "text" => "A small useful project" }
      }.to_return(status: 200, body: reply(text: "一个实用的小项目"))
      assert_equal 1, generate.translated
      assert_requested stub, times: 1
    end
    assert_equal before, @item.reload.attributes.except("summary_zh", "updated_at")
    assert_nil @item.title_zh
  end

  test "不跨源或不同原文复用且忽略旧不合规译文" do
    [ { source_id: sources(:hackaday).id }, { title: "Different original" }, { title_zh: "English only" } ].each_with_index do |changes, rank|
      older = Issue.create!(kind: "daily", period_key: "2026-09-0#{6 - rank}", state: "published", published_at: 2.days.ago, generation_started_at: 2.days.ago)
      Item.create!(@item.attributes.except("id", "issue_id").merge("issue" => older, "rank" => rank + 1, "url_hash" => Digest::SHA256.hexdigest("#{rank}"), "title_zh" => "不能直接复用的译文").merge(changes.stringify_keys))
    end
    # 每次保留同链接，跨源的行不能用；同源原文不同/译文不合规则同样不能用。
    Item.where.not(issue_id: @issue.id).update_all(url_hash: @item.url_hash)
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply(text: "本次正确译文"))
      assert_equal 1, generate.translated
      assert_requested stub, times: 1
    end
  end

  test "跨日合法保留可复用但显式重新评估重新请求" do
    old_issue = Issue.create!(kind: "daily", period_key: "2026-09-07", state: "published", published_at: 1.day.ago, generation_started_at: 1.day.ago)
    old = Item.create!(@item.attributes.except("id", "issue_id").merge("issue" => old_issue))
    old.store_translation(Translations::Parser::Result.new(decision: "unchanged", text: nil), target: old.translation_target, assessed_at: Time.current)
    before = old.reload.attributes
    with_model_provider do
      assert_equal 1, generate.reused
      assert_equal 0, ModelCall.count
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply(text: "重新评估得到译文"))
      assert_equal 1, generate(reassess: true).translated
      assert_requested stub, times: 1
    end
    assert_equal before, old.reload.attributes
    assert_nil @item.reload.translation_preservations.first
  end

  test "操作到期或供应商未配置不请求且返回停止原因" do
    with_model_provider do
      expired = ModelRequests.operation(issued_at: 7.days.ago)
      assert_equal "expired", generate(operation: expired).stop_reason
      Setting.set("model_name", "")
      assert_equal "unconfigured", generate.stop_reason
      assert_equal 0, ModelCall.count
    end
  end

  test "处理途中到期会明确停止，不请求剩余冻结目标" do
    other = Item.create!(@item.attributes.except("id").merge("url_hash" => "c" * 64, "title" => "Another English story", "rank" => 2))
    operation = ModelRequests.operation(issued_at: 7.days.ago + 10.seconds)
    targets = [ @item.translation_target, other.translation_target ]
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
        travel 11.seconds
        { status: 200, body: reply(text: "本次已发请求的合规译文") }
      end
      outcome = generate(operation: operation, targets: targets)
      assert_equal "expired", outcome.stop_reason
      assert_equal 1, outcome.translated
      assert_nil other.reload.title_zh
      assert_requested stub, times: 1
      assert_equal 1, ModelCall.count
    end
  end

  test "重试前到期仍说明停止原因且不追加请求" do
    operation = ModelRequests.operation(issued_at: 7.days.ago + 10.seconds)
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do
        travel 11.seconds
        { status: 200, body: reply(text: "English only") }
      end
      outcome = generate(operation: operation)
      assert_equal "expired", outcome.stop_reason
      assert_requested stub, times: 1
      assert_nil @item.reload.title_zh
      assert_equal [ "invalid" ], ModelCall.pluck(:status)
    end
  end

  private
    def generate(operation: ModelRequests.operation, targets: [ @item.translation_target ], reassess: false)
      Translations::Generator.generate!(@issue, operation: operation, targets: targets, reassess: reassess)
    end

    def reply(decision: "translated", text: nil, **extra)
      content = { decision: decision, text: text }.compact.merge(extra)
      { choices: [ { message: { content: content.to_json } } ], usage: { prompt_tokens: 100, completion_tokens: 40 } }.to_json
    end
end
