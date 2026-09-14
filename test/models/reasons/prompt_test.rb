require "test_helper"

class Reasons::PromptTest < ActiveSupport::TestCase
  test "系统提示定规则，用户消息带画像、标题、说明、来源与元数据" do
    messages = Reasons::Prompt.messages(items(:hn_one), InterestArea.profile_text)
    assert_equal %w[ system user ], messages.map { |m| m[:role] }
    assert_includes messages[0][:content], "20 到 60 字"
    assert_includes messages[0][:content], '{"reason": "...", "interest_tag": "<领域名>"}'
    user = messages[1][:content]
    assert_includes user, "AI / LLM：本地模型部署"
    assert_includes user, "标题：Show HN: A terminal log viewer written in Rust"
    assert_includes user, "说明：（无）"
    assert_includes user, "来源：Hacker News"
    assert_includes user, "元数据：分数 312 · 评论 145"
  end
end
