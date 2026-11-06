require "test_helper"

class Translations::ParserTest < ActiveSupport::TestCase
  test "译文归一化且两个字段各自接受完整上限" do
    assert_equal "简体 中文", Translations::Parser.parse('{"decision":"translated","text":"  简体  中文 \\n"}', field: "title").text
    { "title" => 300, "summary" => 500 }.each do |field, limit|
      result = Translations::Parser.parse({ decision: "translated", text: "文" * limit }.to_json, field: field)
      assert_equal "文" * limit, result.text
      assert_raises(Translations::Parser::Invalid) do
        Translations::Parser.parse({ decision: "translated", text: "文" * (limit + 1) }.to_json, field: field)
      end
    end
  end

  test "合法保留原文只接受单键完整对象" do
    result = Translations::Parser.parse('{"decision":"unchanged"}', field: "title")
    assert_equal "unchanged", result.decision
    assert_nil result.text
    [ { decision: "unchanged", text: nil }, { decision: "unchanged", reason: "资料不足" } ].each do |value|
      assert_raises(Translations::Parser::Invalid) { Translations::Parser.parse(value.to_json, field: "title") }
    end
  end

  test "不从夹杂文字或失败混合对象捡取译文" do
    [ '```json\n{"decision":"translated","text":"中文"}\n```',
      '说明：{"decision":"translated","text":"中文"}', "[]", "null", "{",
      '{"decision":"other"}', '{"decision":"translated"}',
      '{"decision":"translated","text":"English only"}',
      '{"decision":"translated","text":"中文","reason":"理由"}',
      '{"decision":"translated","text":123}' ].each do |text|
      assert_raises(Translations::Parser::Invalid, text) { Translations::Parser.parse(text, field: "title") }
    end
    assert_raises(Translations::Parser::Invalid) { Translations::Parser.parse('{"decision":"unchanged"}', field: "content") }
  end
end
