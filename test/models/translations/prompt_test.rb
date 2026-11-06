require "test_helper"

class Translations::PromptTest < ActiveSupport::TestCase
  test "只发送指定字段，不发送画像链接或另一个原文字段" do
    item = items(:hn_one)
    item.update!(title: "Keep this title", summary: "PRIVATE_OTHER_FIELD")
    messages = Translations::Prompt.messages(item, field: "title")
    assert_equal({ "field" => "title", "text" => "Keep this title" }, JSON.parse(messages.last.fetch(:content)))
    assert_not_includes messages.to_json, "PRIVATE_OTHER_FIELD"
    assert_not_includes messages.to_json, item.url
    assert_equal 320, Translations::Prompt.max_tokens("title")
    assert_equal 600, Translations::Prompt.max_tokens("summary")
  end
end
