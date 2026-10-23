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

  # 画像空着每条都会判「缺领域名」，三次调用三次白花钱：现有生产库里画像本来就是空的
  # （db:prepare 只给新建的库播种），首次发布前这道门必须挡住
  test "画像为空：不调模型、不记账" do
    InterestArea.update_all(enabled: false)
    with_model_provider do
      outcome = Reasons::Generator.generate!(@issue)
      assert outcome.skipped
      assert_not Reasons::Generator.generate_item!(@item)
    end
    assert_equal 0, ModelCall.count
    assert_nil @item.reload.reason
  end

  test "一期全部生成：理由、标签、时间与账本；跑完收掉缺理由事件" do
    open = alert_event(kind: "reasons_missing", source: nil, issue: @issue, dedup_key: "rm")
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，可供前端开发读者考察调试流程。", interest_tag: "AI / LLM", prompt_tokens: 100, completion_tokens: 40))
      outcome = Reasons::Generator.generate!(@issue)
      assert_equal [ 2, 0, 0, false ], [ outcome.generated, outcome.reused, outcome.failed, outcome.skipped ]
    end
    @item.reload
    assert_equal "用 Rust 写的终端日志工具，可供前端开发读者考察调试流程。", @item.reason
    assert_equal "AI / LLM", @item.interest_tag
    assert_not_nil @item.reason_generated_at
    assert_equal 2, ModelCall.where(status: "ok", issue: @issue).count
    assert_equal BigDecimal("0.0005"), ModelCall.first.cost
    assert_not_nil open.reload.recovered_at
  end

  # D25：译文跟理由同一次调用拿回来，不多花一次。HN 与 Hackaday 译标题，GitHub Trending 的标题是仓库名，译简介；
  # 各写各的那一种，模型多给了也不写；输出上限按要译的那段放宽
  test "HN 与 Hackaday 拿回标题译文、GitHub 拿回简介译文，各写各的，输出上限各按各的" do
    @other.update!(summary: "A tiny CLI tool for octo")
    hackaday = Item.create!(source: sources(:hackaday), issue: @issue, title: "A 3D-Printed Rotary Phone", summary: "It actually rings.", url: "https://hackaday.com/rotary-phone", url_hash: Digest::SHA256.hexdigest("https://hackaday.com/rotary-phone"), rank: 1, fetched_at: Time.current)
    titles = { @item.title => "Show HN：一个用 Rust 写的终端日志查看器", hackaday.title => "一部 3D 打印的旋转拨号电话", @other.title => "octo/工具" }
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do |request|
        title = JSON.parse(request.body)["messages"].last["content"][/^标题：(.+)$/, 1]
        { status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，可供前端开发读者考察调试流程。", interest_tag: "AI / LLM", title_zh: titles.fetch(title), summary_zh: "#{title} 的简介译文") }
      end
      assert_equal 3, Reasons::Generator.generate!(@issue).generated
      assert_requested(:post, ReasonsTestHelpers::MODEL_ENDPOINT, times: 2) { |request| JSON.parse(request.body)["max_tokens"] == Reasons::Prompt::MAX_TOKENS + Reasons::Prompt::TITLE_TOKENS }
      assert_requested(:post, ReasonsTestHelpers::MODEL_ENDPOINT, times: 1) { |request| JSON.parse(request.body)["max_tokens"] == Reasons::Prompt::MAX_TOKENS + Reasons::Prompt::SUMMARY_TOKENS }
    end
    assert_equal [ "Show HN：一个用 Rust 写的终端日志查看器", nil ], [ @item.reload.title_zh, @item.summary_zh ]
    assert_equal [ "一部 3D 打印的旋转拨号电话", nil ], [ hackaday.reload.title_zh, hackaday.summary_zh ]
    assert_equal [ nil, "octo/tool 的简介译文" ], [ @other.reload.title_zh, @other.summary_zh ]
    assert_equal 3, ModelCall.count
  end

  # 译文是顺带的：不合规不为它重试、不连累理由；整期重生成这次没译好，也不抹掉上一次的（标题没变，旧译文仍然对得上）
  test "译文不合规只当没有：理由照写；重生成没译好不抹掉旧译文" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，可供前端开发读者考察调试流程。", interest_tag: "AI / LLM", title_zh: "A terminal log viewer"))
      assert Reasons::Generator.generate_item!(@item)
      assert_equal [ "AI / LLM", nil ], [ @item.reload.interest_tag, @item.title_zh ]
      assert_equal [ "ok" ], ModelCall.where(item: @item).pluck(:status)
      assert_requested(:post, ReasonsTestHelpers::MODEL_ENDPOINT, times: 1)

      @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器")
      assert Reasons::Generator.generate_item!(@item)
    end
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", @item.reload.title_zh
    assert_requested(:post, ReasonsTestHelpers::MODEL_ENDPOINT, times: 2)
  end

  test "正文缺领域后重试成功：invalid 记账，失败译文不流入成功结果" do
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(
        { status: 200, body: model_reply(reason: "相关度较低，该条目讨论游戏设计而非技术开发。", interest_tag: "前端开发", title_zh: "失败响应的标题译文") },
        { status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发", prompt_tokens: 200, completion_tokens: 50) }
      )
      assert Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 2
    end
    assert_equal "新的推荐理由，前端开发相关，值得一读，二十字以上。", @item.reload.reason
    assert_nil @item.title_zh
    assert_equal [ [ "invalid", 100, 40, BigDecimal("0.0005"), "理由未点名领域" ], [ "ok", 200, 50, BigDecimal("0.0007"), nil ] ],
                 ModelCall.where(item: @item).order(:id).pluck(:status, :prompt_tokens, :completion_tokens, :cost, :error_summary)
  end

  test "正文连续缺领域：最多三次请求，旧字段和时间保留" do
    @item.update!(reason: "已有推荐理由，前端开发相关，二十个字以上的完整句子。", interest_tag: "前端开发", title_zh: "已有标题译文", summary_zh: "已有简介译文", reason_generated_at: 1.day.ago)
    before = @item.reload.attributes.slice("reason", "interest_tag", "title_zh", "summary_zh", "reason_generated_at", "updated_at")
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "相关度较低，该条目讨论游戏设计而非技术开发。", interest_tag: "前端开发", title_zh: "失败响应的标题译文", summary_zh: "失败响应的简介译文"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 3
    end
    assert_equal before, @item.reload.attributes.slice(*before.keys)
    assert_equal [ [ "invalid", "理由未点名领域" ] ] * 3, ModelCall.where(item: @item).order(:id).pluck(:status, :error_summary)
  end

  test "正文缺领域首次响应耗尽预算：只请求一次并保留旧字段" do
    @item.update!(reason: "已有推荐理由，前端开发相关，二十个字以上的完整句子。", interest_tag: "前端开发", title_zh: "已有标题译文", reason_generated_at: 1.day.ago)
    before = @item.reload.attributes.slice("reason", "interest_tag", "title_zh", "reason_generated_at", "updated_at")
    with_model_provider do
      Setting.set("model_monthly_cap", "0.0005")
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "相关度较低，该条目讨论游戏设计而非技术开发。", interest_tag: "前端开发", title_zh: "失败响应的标题译文"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 1
    end
    assert Reasons::Budget.exhausted?
    assert_equal before, @item.reload.attributes.slice(*before.keys)
    assert_equal [ [ "invalid", BigDecimal("0.0005"), "理由未点名领域" ] ], ModelCall.where(item: @item).pluck(:status, :cost, :error_summary)
  end

  test "超长后重试成功：两次都按实际 usage 记账，失败译文不流入成功结果" do
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(
        { status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM", title_zh: "失败响应的标题译文", prompt_tokens: 100, completion_tokens: 40) },
        { status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发", prompt_tokens: 200, completion_tokens: 50) }
      )
      assert Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 2
    end
    assert_equal [ "新的推荐理由，前端开发相关，值得一读，二十字以上。", "前端开发", nil ], [ @item.reload.reason, @item.interest_tag, @item.title_zh ]
    calls = ModelCall.where(item: @item).order(:id)
    assert_equal [ [ "invalid", 100, 40, BigDecimal("0.0005") ], [ "ok", 200, 50, BigDecimal("0.0007") ] ], calls.pluck(:status, :prompt_tokens, :completion_tokens, :cost)
    assert_equal [ "理由太长（61 字）", nil ], calls.pluck(:error_summary)
  end

  test "简介译文也不从超长失败响应流入后续成功结果" do
    @other.update!(summary: "A tiny CLI tool for octo")
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(
        { status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM", summary_zh: "失败响应的简介译文") },
        { status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发") }
      )
      assert Reasons::Generator.generate_item!(@other)
      assert_requested stub, times: 2
    end
    assert_equal "前端开发", @other.reload.interest_tag
    assert_nil @other.summary_zh
    assert_equal [ "invalid", "ok" ], ModelCall.where(item: @other).order(:id).pluck(:status)
  end

  test "月上限为 0 时最多三次超长失败：不写新字段，每次 invalid 都记录 usage 与费用" do
    before = @item.attributes.slice("reason", "interest_tag", "title_zh", "summary_zh", "reason_generated_at", "updated_at")
    with_model_provider do
      Setting.set("model_monthly_cap", "0")
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM", title_zh: "失败响应的标题译文"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 3
    end
    assert_equal before, @item.reload.attributes.slice(*before.keys)
    assert_equal [ [ "invalid", 100, 40, BigDecimal("0.0005"), "理由太长（61 字）" ] ] * 3,
                 ModelCall.where(item: @item).order(:id).pluck(:status, :prompt_tokens, :completion_tokens, :cost, :error_summary)
    assert_equal BigDecimal("0.0015"), Reasons::Budget.month_cost
  end

  test "手动重生成连续超长失败：旧理由、标签、两种译文与时间完全保留" do
    @item.update!(reason: "已有推荐理由，后端开发相关，二十个字以上的完整句子。", interest_tag: "后端开发", title_zh: "已有标题译文", summary_zh: "已有简介译文", reason_generated_at: 1.day.ago)
    before = @item.reload.attributes.slice("reason", "interest_tag", "title_zh", "summary_zh", "reason_generated_at", "updated_at")
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM", title_zh: "失败响应的标题译文", summary_zh: "失败响应的简介译文"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 3
    end
    assert_equal before, @item.reload.attributes.slice(*before.keys)
    assert_equal [ "invalid" ] * 3, ModelCall.where(item: @item).pluck(:status)
  end

  test "首次超长响应耗尽月预算：记一次 invalid 后不再发请求" do
    with_model_provider do
      Setting.set("model_monthly_cap", "0.0005")
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM", title_zh: "失败响应的标题译文"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 1
    end
    assert_equal [ [ "invalid", BigDecimal("0.0005") ] ], ModelCall.where(item: @item).pluck(:status, :cost)
    assert Reasons::Budget.exhausted?
    assert_nil @item.reload.reason
    assert_nil @item.title_zh
  end

  test "已有的缺领域名失败也必须在每次重试前检查月预算" do
    with_model_provider do
      Setting.set("model_monthly_cap", "0.0005")
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "一" * 30, interest_tag: "不存在"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 1
    end
    assert_equal [ [ "invalid", BigDecimal("0.0005") ] ], ModelCall.where(item: @item).pluck(:status, :cost)
  end

  test "唯一条目首次 invalid 耗尽预算：一次请求一次账本，并立即告警一次" do
    @other.destroy!
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      with_model_provider do
        Setting.set("model_monthly_cap", "0.0005")
        Setting.set("model_input_price", "1")
        Setting.set("model_output_price", "10")
        stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM"))
        assert_equal [ 0, 1 ], Reasons::Generator.generate!(@issue).then { |outcome| [ outcome.generated, outcome.failed ] }
        assert_requested stub, times: 1
      end
      assert_equal [ [ "invalid", 100, 40, BigDecimal("0.0005") ] ], ModelCall.pluck(:status, :prompt_tokens, :completion_tokens, :cost)
      assert_equal 1, AlertEvent.where(kind: "reasons_missing").count
      event = AlertEvent.where(kind: "reasons_missing").sole
      assert_equal "本月费用已达上限，缺理由 1 条", event.summary
      assert_nil event.recovered_at
      assert_enqueued_with(job: DeliverAlertJob, args: [ event, "alert" ])
      assert_enqueued_jobs 1, only: DeliverAlertJob
    end
  end

  test "最后一条 invalid 耗尽预算：不等下一条循环即告警" do
    @other.update!(rank: 2)
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      with_model_provider do
        Setting.set("model_monthly_cap", "0.001")
        Setting.set("model_input_price", "1")
        Setting.set("model_output_price", "10")
        stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(
          { status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发") },
          { status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM") }
        )
        assert_equal [ 1, 1 ], Reasons::Generator.generate!(@issue).then { |outcome| [ outcome.generated, outcome.failed ] }
        assert_requested stub, times: 2
      end
      assert_equal [ "ok", "invalid" ], ModelCall.order(:id).pluck(:status)
      assert_equal 1, AlertEvent.where(kind: "reasons_missing").count
      event = AlertEvent.where(kind: "reasons_missing").sole
      assert_equal "本月费用已达上限，缺理由 1 条", event.summary
      assert_nil event.recovered_at
      assert_enqueued_jobs 1, only: DeliverAlertJob
    end
  end

  test "直接重生成失败耗尽预算：保留旧字段；零缺理由仍保留预算告警且不重复投递" do
    @item.update!(reason: "已有推荐理由，后端开发相关，二十个字以上的完整句子。", interest_tag: "后端开发", title_zh: "已有标题译文", summary_zh: "已有简介译文", reason_generated_at: 1.day.ago)
    @other.update!(reason: "已有推荐理由，前端开发相关，二十个字以上的完整句子。", interest_tag: "前端开发", reason_generated_at: 1.day.ago)
    before = @item.reload.attributes.slice("reason", "interest_tag", "title_zh", "summary_zh", "reason_generated_at", "updated_at")
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      with_model_provider do
        Setting.set("model_monthly_cap", "0.0005")
        Setting.set("model_input_price", "1")
        Setting.set("model_output_price", "10")
        stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM", title_zh: "失败响应的标题译文", summary_zh: "失败响应的简介译文"))
        assert_not Reasons::Generator.generate_item!(@item)
        assert_equal before, @item.reload.attributes.slice(*before.keys)
        assert_equal 1, AlertEvent.where(kind: "reasons_missing").count
        event = AlertEvent.where(kind: "reasons_missing").sole
        assert_equal "本月费用已达上限，已停止生成", event.summary
        assert_nil event.recovered_at

        assert_no_difference("AlertEvent.count") { Reasons::Generator.generate!(@issue, only_missing: false) }
        assert_nil event.reload.recovered_at
        assert_requested stub, times: 1
        assert_equal [ [ "invalid", BigDecimal("0.0005") ] ], ModelCall.pluck(:status, :cost)
        assert_enqueued_with(job: DeliverAlertJob, args: [ event, "alert" ])
        assert_enqueued_jobs 1, only: DeliverAlertJob
      end
    end
  end

  test "第三次 invalid 恰好耗尽预算也立即告警" do
    @other.destroy!
    with_model_provider do
      Setting.set("model_monthly_cap", "0.0015")
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "长" * 61, interest_tag: "AI / LLM"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 3
    end
    assert_equal 3, ModelCall.where(status: "invalid").count
    assert_equal [ "本月费用已达上限，缺理由 1 条" ], AlertEvent.where(kind: "reasons_missing").pluck(:summary)
  end

  test "最后一条成功后恰好达到预算：没有被预算终止，不凭空创建告警" do
    @other.destroy!
    with_model_provider do
      Setting.set("model_monthly_cap", "0.0005")
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发"))
      assert_equal 1, Reasons::Generator.generate!(@issue).generated
      assert_requested stub, times: 1
    end
    assert_equal [ "ok" ], ModelCall.pluck(:status)
    assert_empty AlertEvent.where(kind: "reasons_missing")
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

  # 仓库不变量「429 / 403 不追加重试」：条内不重试，本期也到此为止（设计 C11）
  test "429：只调一次，账本一条 failed，后面的条目不再调" do
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 429, body: "slow down")
      assert_equal 1, Reasons::Generator.generate!(@issue).failed
      assert_requested stub, times: 1
      assert_equal [ "failed" ], ModelCall.pluck(:status)
      assert_equal "模型服务限流（429）", ModelCall.sole.error_summary
    end
    assert_nil @item.reload.reason
  end

  test "403：只调一次，账本一条 failed，后面的条目不再调" do
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 403)
      assert_equal 1, Reasons::Generator.generate!(@issue).failed
      assert_requested stub, times: 1
      assert_equal [ [ "failed", "密钥被拒绝" ] ], ModelCall.pluck(:status, :error_summary)
    end
    assert_nil @item.reload.reason
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

  test "跨天重复的条目沿用前一期的理由与标题译文，不调模型（R-1.11）" do
    @item.update!(reason: "前一天的理由，二十个字以上的中文句子，用来复用。", interest_tag: "AI / LLM", title_zh: "Show HN：一个用 Rust 写的终端日志查看器", reason_generated_at: 1.day.ago)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", published_at: Time.current, generation_started_at: Time.current)
    dup = Item.create!(source: sources(:hn), issue: later, title: @item.title, url: @item.url, url_hash: @item.url_hash, rank: 1, fetched_at: Time.current)
    with_model_provider do
      outcome = Reasons::Generator.generate!(later)
      assert_equal [ 0, 1 ], [ outcome.generated, outcome.reused ]
    end
    assert_equal @item.reason, dup.reload.reason
    assert_equal "AI / LLM", dup.interest_tag
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", dup.title_zh
    assert_equal 0, ModelCall.count
  end

  # D25：沿用的前一条得带着同一个标题的译文。早于译文上线的理由没有译文，HN 版主改过的标题对不上旧译文，
  # 这两种都整条重新生成，不然这条就只有理由、永远等不到译文（补缺只看理由）
  test "前一期没有译文或标题改过：HN 条目不沿用，整条重新生成" do
    @item.update!(reason: "前一天的理由，二十个字以上的中文句子，用来复用。", interest_tag: "AI / LLM", reason_generated_at: 1.day.ago)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", published_at: Time.current, generation_started_at: Time.current)
    dup = Item.create!(source: sources(:hn), issue: later, title: @item.title, url: @item.url, url_hash: @item.url_hash, rank: 1, fetched_at: Time.current)
    latest = Issue.create!(kind: "daily", period_key: "2026-09-10", state: "published", published_at: Time.current, generation_started_at: Time.current)
    renamed = Item.create!(source: sources(:hn), issue: latest, title: "A terminal log viewer in Rust", url: @item.url, url_hash: @item.url_hash, rank: 1, fetched_at: Time.current)
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发", title_zh: "Show HN：一个用 Rust 写的终端日志查看器"))
      assert_equal [ 1, 0 ], Reasons::Generator.generate!(later).then { |outcome| [ outcome.generated, outcome.reused ] }

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发", title_zh: "一个用 Rust 写的终端日志查看器"))
      assert_equal [ 1, 0 ], Reasons::Generator.generate!(latest).then { |outcome| [ outcome.generated, outcome.reused ] }
    end
    assert_equal [ "前端开发", "Show HN：一个用 Rust 写的终端日志查看器" ], [ dup.reload.interest_tag, dup.title_zh ]
    assert_equal "一个用 Rust 写的终端日志查看器", renamed.reload.title_zh
  end

  # GitHub 的仓库常连着几天上榜：简介没变就连理由带简介译文一起沿用；仓库改了简介，旧译文对不上，整条重新生成
  test "GitHub 条目跨天沿用简介译文；简介改过就重新生成" do
    @other.update!(summary: "A tiny CLI tool for octo", summary_zh: "给 octo 用的命令行小工具", reason: "前一天的理由，二十个字以上的中文句子，用来复用。", interest_tag: "AI / LLM", reason_generated_at: 1.day.ago)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", published_at: Time.current, generation_started_at: Time.current)
    same = Item.create!(source: sources(:github), issue: later, title: @other.title, summary: @other.summary, url: @other.url, url_hash: @other.url_hash, rank: 1, fetched_at: Time.current)
    latest = Issue.create!(kind: "daily", period_key: "2026-09-10", state: "published", published_at: Time.current, generation_started_at: Time.current)
    changed = Item.create!(source: sources(:github), issue: latest, title: @other.title, summary: "A tiny CLI tool for octo, now with plugins", url: @other.url, url_hash: @other.url_hash, rank: 1, fetched_at: Time.current)
    with_model_provider do
      assert_equal [ 0, 1 ], Reasons::Generator.generate!(later).then { |outcome| [ outcome.generated, outcome.reused ] }

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，前端开发相关，值得一读，二十字以上。", interest_tag: "前端开发", summary_zh: "给 octo 用的命令行小工具，现在支持插件"))
      assert_equal [ 1, 0 ], Reasons::Generator.generate!(latest).then { |outcome| [ outcome.generated, outcome.reused ] }
    end
    assert_equal [ @other.reason, "给 octo 用的命令行小工具" ], [ same.reload.reason, same.summary_zh ]
    assert_equal "给 octo 用的命令行小工具，现在支持插件", changed.reload.summary_zh
  end

  # HN 帖子链到仓库，第二天仓库上了 Trending（仓库没写简介，没什么可译）：同一个地址，理由照沿用，不带走帖子标题的译文
  test "不译的条目沿用理由，不带走前一条的译文" do
    @item.update!(reason: "前一天的理由，二十个字以上的中文句子，用来复用。", interest_tag: "AI / LLM", title_zh: "Show HN：一个用 Rust 写的终端日志查看器", reason_generated_at: 1.day.ago)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", published_at: Time.current, generation_started_at: Time.current)
    repo = Item.create!(source: sources(:github), issue: later, title: "octo/termlog", url: @item.url, url_hash: @item.url_hash, rank: 1, fetched_at: Time.current)
    with_model_provider { assert_equal 1, Reasons::Generator.generate!(later).reused }
    assert_equal @item.reason, repo.reload.reason
    assert_nil repo.title_zh
    assert_nil repo.summary_zh
  end

  # 沿用只在补缺时算数：整期重生成要能把跨天沿用来的理由也换掉，不然这个按钮对重复条目没有效果
  test "整期重生成覆盖跨天沿用来的理由" do
    @item.update!(reason: "前一天的理由，二十个字以上的中文句子，用来复用。", interest_tag: "AI / LLM", title_zh: "Show HN：一个用 Rust 写的终端日志查看器", reason_generated_at: 1.day.ago)
    later = Issue.create!(kind: "daily", period_key: "2026-09-09", state: "published", published_at: Time.current, generation_started_at: Time.current)
    dup = Item.create!(source: sources(:hn), issue: later, title: @item.title, url: @item.url, url_hash: @item.url_hash, rank: 1, fetched_at: Time.current)
    with_model_provider do
      assert_equal 1, Reasons::Generator.generate!(later).reused

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "重新写过的推荐理由，前端开发相关，二十字以上。", interest_tag: "前端开发"))
      assert_equal 1, Reasons::Generator.generate!(later, only_missing: false).generated
    end
    assert_equal [ "重新写过的推荐理由，前端开发相关，二十字以上。", "前端开发" ], [ dup.reload.reason, dup.interest_tag ]
  end
end
