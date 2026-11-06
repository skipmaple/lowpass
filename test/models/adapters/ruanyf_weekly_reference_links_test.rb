require "test_helper"

class Adapters::RuanyfWeeklyReferenceLinksTest < ActiveSupport::TestCase
  test "引用地址与清洗正文逐字对应，包括非 BMP 字符" do
    body = "🙂 看[站点](https://example.com/a)，再看[代码](https://example.com/b)。"
    content = SummaryCleaner.content(body)
    assert_equal [ [ 0, 3, 5, "https://example.com/a" ], [ 0, 8, 10, "https://example.com/b" ] ],
      Adapters::RuanyfWeekly::ReferenceLinks.for(body: body, content: content, issue_no: 415)
    assert_nil Adapters::RuanyfWeekly::ReferenceLinks.for(body: body, content: "别的正文", issue_no: 415)
  end

  test "不能安全识别的代码、嵌套、HTML、危险地址和被截断正文不产生链接" do
    [ "`[代码](https://example.com)`", "[嵌套 [名]](https://example.com)",
      "<code>[代码](https://example.com)</code>", "[执行](javascript:alert)",
      "[用户](https://user:pass@example.com/)" ].each do |body|
      assert_nil Adapters::RuanyfWeekly::ReferenceLinks.for(body: body, content: SummaryCleaner.content(body), issue_no: 415), body
    end
  end

  test "新周刊保留链接位置并继续存储纯文本" do
    body = "# 科技爱好者周刊（第 999 期）：测试\n\n## 专题\n\n查看[代码](https://example.com/code)。\n"
    parsed = Adapters::RuanyfWeekly::Markdown.parse(body)
    raw = parsed[:sections].first[:items].first
    entry = Adapters::RuanyfWeekly.allocate.send(:entry, raw, parsed, 999, 1)
    attrs = entry.to_item_attributes(source: sources(:ruanyf), issue: issues(:weekly_w36))
    assert_equal "查看代码。", attrs[:content]
    assert_equal [ [ 0, 2, 4, "https://example.com/code" ] ], attrs[:meta][:reference_links]
  end
end
