require "test_helper"

class Reasons::GeneratorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @issue = issues(:daily_0908)
    @item = items(:hn_one)
    @other = Item.create!(source: sources(:github), issue: @issue, title: "octo/tool", url: "https://github.com/octo/tool", url_hash: Digest::SHA256.hexdigest("https://github.com/octo/tool"), rank: 1, fetched_at: Time.current, meta: { "stars" => 10, "language" => "Go" })
    # 此文件验证生成流程；原文 HTTP 与解析边界由 EvidenceTest 独立覆盖。
    Reasons::Evidence.stubs(:fetch).returns(Reasons::Evidence::Result.new(text: "The tool streams local log files, filters entries by level, and exports matching events as JSON.", url: @item.url, error: nil))
  end

  test "无说明条目先读正文，只调用一次模型且不改写刊物原字段" do
    evidence = Reasons::Evidence::Result.new(text: "Streams logs with filters and aggregation without loading the full file.", url: @item.url, error: nil)
    Reasons::Evidence.expects(:fetch).with(@item).once.returns(evidence)
    before = @item.attributes.slice("title", "url", "summary", "content")
    with_model_provider do
      request = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).with { |r| JSON.parse(r.body)["messages"].last["content"].include?(evidence.text) }
        .to_return(status: 200, body: model_reply(reason: "流式过滤与聚合避免整份日志载入内存，可借鉴其处理大文件的方法。", interest_tag: "前端开发"))
      assert Reasons::Generator.generate_item!(@item)
      assert_requested request, times: 1
    end
    assert_equal before, @item.reload.attributes.slice("title", "url", "summary", "content")
  end

  test "短简介即使模型会直接回答，也先补读 README 供首次请求判断" do
    @other.update!(summary: "Agent Skills for Google products and technologies.", meta: { "language" => "Python" })
    evidence = Reasons::Evidence::Result.new(text: "Install skills with npx skills add google/skills. The repository contains instructions for agents using Google products and Google Cloud.", url: @other.url, error: nil)
    Reasons::Evidence.expects(:fetch).with(@other).once.returns(evidence)
    first_prompt = nil
    with_model_provider do
      request = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do |r|
        first_prompt = JSON.parse(r.body)["messages"].last["content"]
        { status: 200, body: model_reply(reason: "按产品安装所需技能说明，帮助智能体采用对应的工具和工作流程。", interest_tag: "AI / LLM") }
      end

      assert Reasons::Generator.generate_item!(@other)

      assert_requested request, times: 1
      assert_includes first_prompt, evidence.text
    end
    assert_equal [ "ok" ], ModelCall.pluck(:status)
  end

  test "较长简介仍不足时只补读一次原文，用新资料重试而非重复空输入" do
    @other.update!(summary: "An agent toolkit for developers exploring new ways of working with modern technologies. Learn more about the project and its available resources in the repository.")
    evidence = Reasons::Evidence::Result.new(text: "Provides reproducible browser workflows with assertions and execution traces.", url: @other.url, error: nil)
    Reasons::Evidence.expects(:fetch).with(@other).once.returns(evidence)
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do |r|
        reason = JSON.parse(r.body)["messages"].last["content"].include?(evidence.text) ? "通过断言与执行轨迹复现浏览器工作流，便于定位智能体操作中的偏差。" : ""
        { status: 200, body: model_reply(reason: reason, interest_tag: "AI / LLM") }
      end
      assert Reasons::Generator.generate_item!(@other)
      assert_requested :post, ReasonsTestHelpers::MODEL_ENDPOINT, times: 2
    end
    assert_equal %w[ invalid ok ], ModelCall.order(:created_at).pluck(:status)
  end

  test "原文失败保留具体原因，不重复抓取或清掉旧理由" do
    @item.update!(reason: "旧理由", title_zh: "旧译文")
    Reasons::Evidence.expects(:fetch).with(@item).once.returns(Reasons::Evidence::Result.new(text: nil, url: @item.url, error: "原文获取失败：访问被拒绝（403/429）"))
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "", interest_tag: "AI / LLM"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 1
    end
    assert_equal "原文获取失败：访问被拒绝（403/429）", ModelCall.sole.error_summary
    assert_equal [ "旧理由", "旧译文" ], [ @item.reload.reason, @item.title_zh ]
  end

  test "无摘要且原文失败，即使模型猜出格式合法的理由也不能落库" do
    @item.update!(reason: "已确认的旧理由", title_zh: "已确认的旧译文")
    before = @item.attributes.slice("reason", "title_zh", "reason_generated_at")
    Reasons::Evidence.expects(:fetch).with(@item).once.returns(Reasons::Evidence::Result.new(text: nil, url: @item.url, error: "原文资料不足：未提取到可用正文"))
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200,
        body: model_reply(reason: "采用流式解析避免将整个文件读入内存，方便分析大规模日志。", interest_tag: "AI / LLM", title_zh: "猜测的新译文"))
      assert_not Reasons::Generator.generate_item!(@item)
      assert_requested stub, times: 1
    end
    assert_equal before, @item.reload.attributes.slice("reason", "title_zh", "reason_generated_at")
    assert_equal [ "invalid", "原文资料不足：未提取到可用正文" ], ModelCall.sole.then { |call| [ call.status, call.error_summary ] }
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

  # D25：译文跟理由同一次调用拿回来，不多花一次。HN 与 Hackaday 译标题，GitHub Trending 的标题是仓库名，译简介；
  # 各写各的那一种，模型多给了也不写；输出上限按要译的那段放宽
  test "HN 与 Hackaday 拿回标题译文、GitHub 拿回简介译文，各写各的，输出上限各按各的" do
    @other.update!(summary: "A tiny CLI tool for octo")
    hackaday = Item.create!(source: sources(:hackaday), issue: @issue, title: "A 3D-Printed Rotary Phone", summary: "It actually rings.", url: "https://hackaday.com/rotary-phone", url_hash: Digest::SHA256.hexdigest("https://hackaday.com/rotary-phone"), rank: 1, fetched_at: Time.current)
    titles = { @item.title => "Show HN：一个用 Rust 写的终端日志查看器", hackaday.title => "一部 3D 打印的旋转拨号电话", @other.title => "octo/工具" }
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do |request|
        title = JSON.parse(request.body)["messages"].last["content"][/^标题：(.+)$/, 1]
        { status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。", interest_tag: "AI / LLM", title_zh: titles.fetch(title), summary_zh: "#{title} 的简介译文") }
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
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。", interest_tag: "AI / LLM", title_zh: "A terminal log viewer"))
      assert Reasons::Generator.generate_item!(@item)
      assert_equal [ "AI / LLM", nil ], [ @item.reload.interest_tag, @item.title_zh ]
      assert_equal [ "ok" ], ModelCall.where(item: @item).pluck(:status)

      @item.update!(title_zh: "Show HN：一个用 Rust 写的终端日志查看器")
      assert Reasons::Generator.generate_item!(@item)
    end
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", @item.reload.title_zh
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

  test "明确资料不足只调用一次并记账，不覆盖现有理由与译文" do
    @item.update!(reason: "原有理由", interest_tag: "AI / LLM", title_zh: "原有中文标题", reason_generated_at: 1.day.ago)
    before = @item.attributes.slice("reason", "interest_tag", "title_zh", "reason_generated_at")
    with_model_provider do
      stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200,
        body: model_reply(reason: "", interest_tag: "前端开发", title_zh: "这次译文", prompt_tokens: 100, completion_tokens: 40))

      assert_not Reasons::Generator.generate_item!(@item)

      assert_requested stub, times: 1
    end
    assert_equal before, @item.reload.attributes.slice("reason", "interest_tag", "title_zh", "reason_generated_at")
    assert_equal [ "invalid", "条目资料不足，未生成理由", 100, 40 ],
      ModelCall.sole.then { |call| [ call.status, call.error_summary, call.prompt_tokens, call.completion_tokens ] }
  end

  test "资料不足不阻止同一期其余条目继续生成" do
    with_model_provider do
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return do |request|
        prompt = JSON.parse(request.body)["messages"].last["content"]
        reason = prompt.include?("标题：#{@item.title}\n") ? "" : "这个工具通过命令行处理日常操作，能省去重复的手工步骤。"
        { status: 200, body: model_reply(reason: reason, interest_tag: "AI / LLM") }
      end

      outcome = Reasons::Generator.generate!(@issue)

      assert_equal [ 1, 1 ], [ outcome.generated, outcome.failed ]
      assert_requested :post, ReasonsTestHelpers::MODEL_ENDPOINT, times: 2
    end
    assert_nil @item.reload.reason
    assert_not_nil @other.reload.reason
  end

  test "错误结构与非法标签仍重试，不能冒充资料不足" do
    with_model_provider do
      [
        "broken json",
        { interest_tag: "AI / LLM" }.to_json,
        { reason: nil, interest_tag: "AI / LLM" }.to_json,
        { reason: [ "一" * 30 ], interest_tag: "AI / LLM" }.to_json,
        { reason: "", interest_tag: "不存在" }.to_json,
        { reason: "太短", interest_tag: "AI / LLM" }.to_json
      ].each do |content|
        response = Reasons::Provider::Response.new(text: content, prompt_tokens: 100, completion_tokens: 40)
        Reasons::Provider.expects(:chat).times(3).returns(response)
        assert_difference -> { ModelCall.where(item: @item, status: "invalid").count }, 3 do
          assert_not Reasons::Generator.generate_item!(@item)
        end
      end
    end
    assert_nil @item.reload.reason
    assert_not ModelCall.exists?(error_summary: "条目资料不足，未生成理由")
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

  test "长度截断只记一次真实用量，不重复请求或覆盖旧理由译文" do
    @item.update!(reason: "原有理由", interest_tag: "AI / LLM", title_zh: "原有中文标题", reason_generated_at: 1.day.ago)
    before = @item.attributes.slice("reason", "interest_tag", "title_zh", "reason_generated_at")
    with_model_provider do
      Setting.set("model_input_price", "1")
      Setting.set("model_output_price", "10")
      reply = JSON.parse(model_reply(reason: "看起来完整的推荐理由也不能绕过服务端的截断标记而覆盖旧内容。", interest_tag: "前端开发", title_zh: "不应保存的译文", prompt_tokens: 456, completion_tokens: 2047))
      reply["choices"].first["finish_reason"] = "length"
      request = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: reply.to_json)

      assert_not Reasons::Generator.generate_item!(@item)

      assert_requested request, times: 1
    end
    assert_equal before, @item.reload.attributes.slice("reason", "interest_tag", "title_zh", "reason_generated_at")
    assert_equal [ "failed", 456, 2047, BigDecimal("0.0209"), "模型输出达到长度上限，未生成完整回复" ],
      ModelCall.sole.then { |call| [ call.status, call.prompt_tokens, call.completion_tokens, call.cost, call.error_summary ] }
  end

  test "空内容截断的真实费用计入上限，阻止同一期后续请求" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      with_model_provider do
        Setting.set("model_monthly_cap", "0.01")
        Setting.set("model_output_price", "10")
        request = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: {
          choices: [ { finish_reason: "length", message: { content: "", reasoning_content: "尚未给出最终答案" } } ],
          usage: { prompt_tokens: 456, completion_tokens: 2047 }
        }.to_json)

        outcome = Reasons::Generator.generate!(@issue)

        assert_equal [ 0, 1 ], [ outcome.generated, outcome.failed ]
        assert_requested request, times: 1
        assert Reasons::Budget.exhausted?
      end
    end
    assert_nil @item.reload.reason
    assert_nil @other.reload.reason
    assert_equal 2047, ModelCall.sole.completion_tokens
    assert_match(/本月费用已达上限/, AlertEvent.find_by!(kind: "reasons_missing").summary)
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
      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，开发者效率相关，值得一读，二十字以上。", interest_tag: "前端开发", title_zh: "Show HN：一个用 Rust 写的终端日志查看器"))
      assert_equal [ 1, 0 ], Reasons::Generator.generate!(later).then { |outcome| [ outcome.generated, outcome.reused ] }

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，开发者效率相关，值得一读，二十字以上。", interest_tag: "前端开发", title_zh: "一个用 Rust 写的终端日志查看器"))
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

      stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: model_reply(reason: "新的推荐理由，开发者效率相关，值得一读，二十字以上。", interest_tag: "前端开发", summary_zh: "给 octo 用的命令行小工具，现在支持插件"))
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
