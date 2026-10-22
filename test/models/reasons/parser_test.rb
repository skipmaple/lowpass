require "test_helper"

class Reasons::ParserTest < ActiveSupport::TestCase
  NAMES = [ "AI / LLM", "前端开发" ].freeze

  test "整段 JSON 与夹在文字里的 JSON 都能解析；空白收成一个空格" do
    text = { reason: "这个用 Rust 写的终端日志工具  对\n开发者效率很有帮助，值得一看。", interest_tag: "前端开发" }.to_json
    result = Reasons::Parser.parse(text, NAMES)
    assert_equal "这个用 Rust 写的终端日志工具 对 开发者效率很有帮助，值得一看。", result.reason
    assert_equal "前端开发", result.interest_tag

    wrapped = "好的，结果如下：\n#{text}\n希望有帮助。"
    assert_equal "前端开发", Reasons::Parser.parse(wrapped, NAMES).interest_tag
  end

  test "太短、缺领域名、领域名不在画像里、不是 JSON 都判失败" do
    assert_equal "理由太短（5 字）", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse({ reason: "太短了吧啊", interest_tag: "前端开发" }.to_json, NAMES) }.message
    assert_equal "缺领域名", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse({ reason: "一" * 30 }.to_json, NAMES) }.message
    assert_equal "缺领域名", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse({ reason: "一" * 30, interest_tag: "不存在" }.to_json, NAMES) }.message
    assert_equal "不是 JSON", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse("抱歉，我不能", NAMES) }.message
    assert_equal "不是 JSON", assert_raises(Reasons::Parser::Invalid) { Reasons::Parser.parse("[1,2]", NAMES) }.message
  end

  test "理由归一化后 19 字拒绝，20 与 60 字完整返回，61 字拒绝" do
    [ 19, 61 ].each do |length|
      error = assert_raises(Reasons::Parser::Invalid) do
        Reasons::Parser.parse({ reason: "字" * length, interest_tag: "AI / LLM" }.to_json, NAMES)
      end
      assert_equal "理由太#{length == 19 ? '短' : '长'}（#{length} 字）", error.message
    end

    [ 20, 60 ].each do |length|
      reason = "字" * length
      assert_equal reason, Reasons::Parser.parse({ reason: reason, interest_tag: "AI / LLM" }.to_json, NAMES).reason
    end
  end

  test "按归一化后的字符数验收，多余空白不使 60 字误失败" do
    reason = "界" * 47 + " Claude Code。"
    raw = " \t#{'界' * 47} \n Claude\t Code。 \r\n"
    assert_equal 60, reason.length
    assert_operator raw.length, :>, 60
    assert_equal reason, Reasons::Parser.parse({ reason: raw, interest_tag: "AI / LLM" }.to_json, NAMES).reason

    error = assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ reason: " \t#{'界' * 48} \n Claude\t Code。 \r\n", interest_tag: "AI / LLM" }.to_json, NAMES)
    end
    assert_equal "理由太长（61 字）", error.message
  end

  test "超长理由包含项目名时拒绝整条，错误只记录归一化长度" do
    reason = "契合 AI / LLM 领域的 Agent 框架兴趣：Orca 可用自有订阅统一调度 Grok Bot、Claude Code 等编码智能体舰队。"
    error = assert_raises(Reasons::Parser::Invalid) do
      Reasons::Parser.parse({ reason: reason, interest_tag: "AI / LLM" }.to_json, NAMES)
    end
    assert_equal "理由太长（73 字）", error.message
  end

  REASON = "这个用 Rust 写的终端日志工具对开发者效率很有帮助，值得一看。".freeze

  test "标题译文去首尾空白、空白收成一个空格" do
    result = Reasons::Parser.parse({ reason: REASON, interest_tag: "前端开发", title_zh: "  Show HN：一个用  Rust\n写的终端日志查看器 " }.to_json, NAMES)
    assert_equal "Show HN：一个用 Rust 写的终端日志查看器", result.title_zh
    assert_equal REASON, result.reason
  end

  # D25：译文是顺带的，不合规只当没有，理由照常通过——不能为了一句译文把理由也重试掉
  test "译文缺失、不是字符串、不含汉字、超过 300 字都当没有，不判失败" do
    [ nil, "", "   ", 42, [ "终端日志查看器" ], "A terminal log viewer", "译" * 301 ].each do |value|
      result = Reasons::Parser.parse({ reason: REASON, interest_tag: "前端开发", title_zh: value }.to_json, NAMES)
      assert_nil result.title_zh, value.inspect
      assert_equal "前端开发", result.interest_tag
    end
    assert_equal "译" * 300, Reasons::Parser.parse({ reason: REASON, interest_tag: "前端开发", title_zh: "译" * 300 }.to_json, NAMES).title_zh
  end

  test "简介译文同一套规则，上限 500 字" do
    result = Reasons::Parser.parse({ reason: REASON, interest_tag: "前端开发", summary_zh: " 一个 Rust 写的\n命令行小工具 " }.to_json, NAMES)
    assert_equal "一个 Rust 写的 命令行小工具", result.summary_zh
    assert_nil result.title_zh

    assert_equal "译" * 500, Reasons::Parser.parse({ reason: REASON, interest_tag: "前端开发", summary_zh: "译" * 500 }.to_json, NAMES).summary_zh
    [ "A tiny CLI tool", "译" * 501, { "zh" => "小工具" } ].each do |value|
      assert_nil Reasons::Parser.parse({ reason: REASON, interest_tag: "前端开发", summary_zh: value }.to_json, NAMES).summary_zh, value.inspect
    end
  end
end
