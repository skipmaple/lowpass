require "test_helper"

class Reasons::ParserTest < ActiveSupport::TestCase
  NAMES = [ "AI / LLM", "前端开发" ].freeze

  test "合法标签不能代替正文中缺失的画像领域名" do
    error = assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: "相关度较低，该条目讨论游戏设计而非技术开发。", interest_tag: "前端开发" }.to_json, NAMES)
    end
    assert_equal "理由未点名领域", error.message
  end

  test "正文必须点名标签选择的同一个领域" do
    assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: "这个终端工具可供前端开发读者考察调试流程，相关度中等。", interest_tag: "AI / LLM" }.to_json, NAMES)
    end
  end

  test "正文领域名不接受去掉空格的别名" do
    assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: "AI/LLM 推理服务工具，可供部署场景的比较与学习参考。", interest_tag: "AI / LLM" }.to_json, NAMES)
    end
  end

  test "正文领域名在既有空白归一化之后识别" do
    reason = "可供 AI / LLM 读者考察推理服务方案，相关度中等。"
    raw = "可供 AI \n /\t LLM 读者考察推理服务方案，相关度中等。"
    assert_equal reason, Reasons::Parser.parse({ decision: "generated", reason: raw, interest_tag: "AI / LLM" }.to_json, NAMES).reason
  end

  test "领域名称的连续空白随正文归一化，标签仍逐字匹配" do
    name = "AI  /  LLM"
    reason = "可供#{name}读者考察推理服务方案，相关度中等。"
    begin
      result = Reasons::Parser.parse({ decision: "generated", reason: reason, interest_tag: name }.to_json, [ name ])
    rescue Reasons::Parser::Invalid => error
      flunk "合法领域名在归一化后应可用：#{error.message}"
    end
    assert_equal "可供AI / LLM读者考察推理服务方案，相关度中等。", result.reason
    assert_equal name, result.interest_tag

    assert_equal "缺领域名", assert_raises(Reasons::Parser::Invalid) {
      Reasons::Parser.parse({ decision: "generated", reason: reason, interest_tag: "AI / LLM" }.to_json, [ name ])
    }.message
  end

  test "整段 JSON 与夹在文字里的 JSON 都能解析；空白收成一个空格" do
    text = { decision: "generated", reason: "这个用 Rust 写的终端日志工具  对\n前端开发很有帮助，值得一看。", interest_tag: "前端开发" }.to_json
    result = Reasons::Parser.parse(text, NAMES)
    assert_equal "这个用 Rust 写的终端日志工具 对 前端开发很有帮助，值得一看。", result.reason
    assert_equal "前端开发", result.interest_tag

    wrapped = "好的，结果如下：\n#{text}\n希望有帮助。"
    assert_equal "前端开发", Reasons::Parser.parse(wrapped, NAMES).interest_tag
  end

  test "太短、缺领域名、领域名不在画像里、不是 JSON 都判失败" do
    assert_equal "理由太短（5 字）", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse({ decision: "generated", reason: "太短了吧啊", interest_tag: "前端开发" }.to_json, NAMES) }.message
    assert_equal "缺领域名", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse({ decision: "generated", reason: "一" * 30 }.to_json, NAMES) }.message
    assert_equal "缺领域名", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse({ decision: "generated", reason: "一" * 30, interest_tag: "不存在" }.to_json, NAMES) }.message
    assert_equal "不是 JSON", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse("抱歉，我不能", NAMES) }.message
    assert_equal "不是 JSON", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse("[1,2]", NAMES) }.message
  end

  test "理由归一化后 19 字拒绝，20 与 60 字完整返回，61 字拒绝" do
    [ 19, 61 ].each do |length|
      error = assert_raises(Reasons::Parser::Invalid) do
        Reasons::Parser.parse({ decision: "generated", reason: "字" * length, interest_tag: "AI / LLM" }.to_json, NAMES)
      end
      assert_equal "理由太#{length == 19 ? '短' : '长'}（#{length} 字）", error.message
    end

    [ 20, 60 ].each do |length|
      reason = "前端开发" + "字" * (length - 4)
      assert_equal reason, Reasons::Parser.parse({ decision: "generated", reason: reason, interest_tag: "前端开发" }.to_json, NAMES).reason
    end
  end

  test "按归一化后的字符数验收，多余空白不使 60 字误失败" do
    reason = "前端开发" + "界" * 43 + " Claude Code。"
    raw = " \t前端开发#{'界' * 43} \n Claude\t Code。 \r\n"
    assert_equal 60, reason.length
    assert_operator raw.length, :>, 60
    assert_equal reason, Reasons::Parser.parse({ decision: "generated", reason: raw, interest_tag: "前端开发" }.to_json, NAMES).reason

    error = assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: " \t前端开发#{'界' * 44} \n Claude\t Code。 \r\n", interest_tag: "AI / LLM" }.to_json, NAMES)
    end
    assert_equal "理由太长（61 字）", error.message
  end

  test "超长理由包含项目名时拒绝整条，错误只记录归一化长度" do
    reason = "契合 AI / LLM 领域的 Agent 框架兴趣：Orca 可用自有订阅统一调度 Grok Bot、Claude Code 等编码智能体舰队。"
    error = assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: reason, interest_tag: "AI / LLM" }.to_json, NAMES)
    end
    assert_equal "理由太长（73 字）", error.message
  end

  REASON = "这个用 Rust 写的终端日志工具对前端开发很有帮助，值得一看。".freeze

  test "标题译文去首尾空白、空白收成一个空格" do
    result = Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发", title_zh: "  Show HN：一个用  Rust\n写的终端日志查看器 " }.to_json, NAMES)
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", result.title_zh
    assert_equal REASON, result.reason
  end

  # D25：译文是顺带的，不合规只当没有，理由照常通过——不能为了一句译文把理由也重试掉
  test "译文缺失、不是字符串、不含汉字、超过 300 字都当没有，不判失败" do
    [ nil, "", "   ", 42, [ "终端日志查看器" ], "A terminal log viewer", "译" * 301 ].each do |value|
      result = Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发", title_zh: value }.to_json, NAMES)
      assert_nil result.title_zh, value.inspect
      assert_equal "前端开发", result.interest_tag
    end
    assert_equal "译" * 300, Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发", title_zh: "译" * 300 }.to_json, NAMES).title_zh
  end

  test "简介译文同一套规则，上限 500 字" do
    result = Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发", summary_zh: " 一个 Rust 写的\n命令行小工具 " }.to_json, NAMES)
    assert_equal "一个 Rust 写的 命令行小工具", result.summary_zh
    assert_nil result.title_zh

    assert_equal "译" * 500, Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发", summary_zh: "译" * 500 }.to_json, NAMES).summary_zh
    [ "A tiny CLI tool", "译" * 501, { "zh" => "小工具" } ].each do |value|
      assert_nil Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发", summary_zh: value }.to_json, NAMES).summary_zh, value.inspect
    end
  end

  test "合法拒写是无内容的独立结果且外层提取不放宽校验" do
    text = { decision: "insufficient_evidence" }.to_json
    [ text, "说明：#{text}", "```json\n#{text}\n```" ].each do |wrapped|
      result = Reasons::Parser.parse(wrapped, NAMES)
      assert_equal "insufficient_evidence", result.decision
      assert_equal [ nil, nil, nil, nil ], [ result.reason, result.interest_tag, result.title_zh, result.summary_zh ]
    end
    assert_equal "generated", Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: "前端开发" }.to_json, NAMES).decision
  end

  test "拒写任何多余字段包括空值均不合法" do
    %w[ reason interest_tag title_zh summary_zh diagnostic ].each do |key|
      [ nil, "", "额外内容" ].each do |value|
        json = { "decision" => "insufficient_evidence", key => value }.to_json
        [ json, "说明：#{json}", "```json\n#{json}\n```" ].each do |wrapped|
          assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse(wrapped, NAMES) }
        end
      end
    end
  end

  test "缺少或未知判别值不能自动成为拒写" do
    [ {}, { reason: REASON, interest_tag: "前端开发" }, { decision: nil }, { decision: "unknown" }, [], 42, nil ].each do |json|
      assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse(json.to_json, NAMES) }
    end
    assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse("", NAMES) }
  end

  test "生成的理由与标签必须为字符串且理由含汉字" do
    [ 12345678901234567890, [ REASON ], { text: REASON }, nil ].each do |reason|
      assert_raises(Reasons::Parser::Invalid) do
        Reasons::Parser.parse({ decision: "generated", reason: reason, interest_tag: "前端开发" }.to_json, NAMES)
      end
    end
    assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: "AI / LLM supports useful technical reading perspectives.", interest_tag: "AI / LLM" }.to_json, NAMES)
    end
    assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ decision: "generated", reason: REASON, interest_tag: " 前端开发 " }.to_json, NAMES)
    end
  end
end
