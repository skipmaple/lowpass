require "test_helper"

class Adapters::RuanyfWeeklyEmphasisTest < ActiveSupport::TestCase
  test "只识别与清洗正文一一对应的独立加粗段落" do
    body = "开场。\n\n**（1）第一项（Code review）。**\n说明。\n**（2）第二项。**\n结尾。"
    content = SummaryCleaner.content(body)

    assert_equal [ 1, 3 ], Adapters::RuanyfWeekly::ParagraphEmphasis.for(body: body, content: content)
    assert_nil Adapters::RuanyfWeekly::ParagraphEmphasis.for(body: body, content: content + "改变")
  end

  test "代码块、混合标记与普通编号不会被误认为作者强调" do
    [ "```\n**代码示例**\n```", "<pre>\n**代码示例**\n</pre>" ].each do |body|
      assert_nil Adapters::RuanyfWeekly::ParagraphEmphasis.for(body: body, content: SummaryCleaner.content(body))
    end
    body = "（1）普通编号。\n**强调的一部分**和普通文字。\n**未闭合\n  \t**缩进代码**\n\\**转义内容**"
    assert_nil Adapters::RuanyfWeekly::ParagraphEmphasis.for(body: body, content: SummaryCleaner.content(body))
    body = "普通。\n" * 2048 + "**标题**"
    assert_nil Adapters::RuanyfWeekly::ParagraphEmphasis.for(body: body, content: SummaryCleaner.content(body))
  end

  test "新抓取的明确加粗段落随条目存下位置，但正文仍为纯文本" do
    text = "# 科技爱好者周刊（第 999 期）：测试\n\n## 主题\n\n开头。\n\n**（1）重点。**\n\n解释。\n"
    parsed = Adapters::RuanyfWeekly::Markdown.parse(text)
    raw = parsed.fetch(:sections).first.fetch(:items).first
    entry = Adapters::RuanyfWeekly.allocate.send(:entry, raw, parsed, 999, 1)
    attrs = entry.to_item_attributes(source: sources(:ruanyf), issue: issues(:weekly_w36))
    assert_equal "开头。\n（1）重点。\n解释。", attrs[:content]
    assert_equal [ 1 ], attrs[:meta][:emphasis_positions]
  end
end
