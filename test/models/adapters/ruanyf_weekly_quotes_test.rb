require "test_helper"

class Adapters::RuanyfWeeklyQuotesTest < ActiveSupport::TestCase
  test "从与正文完全一致的原文识别引用及引用中的分段" do
    body = "引言。\n\n> 引用第一段。\n>\n> 引用第二段。\n\n正文。"
    content = SummaryCleaner.content(body)
    assert_equal [ [ 1, 4 ] ], Adapters::RuanyfWeekly::QuoteRanges.for(body: body, content: content)
    assert_nil Adapters::RuanyfWeekly::QuoteRanges.for(body: body, content: content + "改变")
  end

  test "隔开的引用分别保留，代码与嵌套引用不推断" do
    body = "> 第一段。\n\n> 第二段。"
    assert_equal [ [ 0, 1 ], [ 1, 2 ] ], Adapters::RuanyfWeekly::QuoteRanges.for(body: body, content: SummaryCleaner.content(body))
    [ "```\n> 代码\n```", "<pre>\n> 代码\n</pre>", "> > 嵌套引用", "    > 缩进代码" ].each do |raw|
      assert_nil Adapters::RuanyfWeekly::QuoteRanges.for(body: raw, content: SummaryCleaner.content(raw)), raw
    end
  end

  test "新抓取条目保存引用位置，正文仍为原来的纯文本" do
    text = "# 科技爱好者周刊（第 999 期）：测试\n\n## 主题\n\n介绍。\n\n> 引用。\n"
    parsed = Adapters::RuanyfWeekly::Markdown.parse(text)
    raw = parsed.fetch(:sections).first.fetch(:items).first
    entry = Adapters::RuanyfWeekly.allocate.send(:entry, raw, parsed, 999, 1)
    attrs = entry.to_item_attributes(source: sources(:ruanyf), issue: issues(:weekly_w36))
    assert_equal "介绍。\n> 引用。", attrs[:content]
    assert_equal [ [ 1, 2 ] ], attrs[:meta][:quote_ranges]
  end
end
