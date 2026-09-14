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

  test "超过 60 字截到 60" do
    result = Reasons::Parser.parse({ reason: "长" * 80, interest_tag: "AI / LLM" }.to_json, NAMES)
    assert_equal 60, result.reason.length
  end
end
