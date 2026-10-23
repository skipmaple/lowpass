require "test_helper"

class Adapters::RuanyfWeeklyTest < ActiveSupport::TestCase
  RAW = "https://raw.githubusercontent.com/ruanyf/weekly/master"
  ISSUES = Dir.glob(File.join(file_fixture_path, "ruanyf/issue-*.md")).sort

  setup do
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "#{RAW}/README.md").to_return(body: file_fixture("ruanyf/README.md").read)
    ISSUES.each do |path|
      n = path[/issue-(\d+)/, 1]
      stub_request(:get, "#{RAW}/docs/issue-#{n}.md").to_return(body: File.read(path))
    end
  end

  test "近 20 期样本都能拆出板块与至少 5 条" do
    assert_equal 20, ISSUES.size

    ISSUES.each do |path|
      text = File.read(path)
      parsed = Adapters::RuanyfWeekly::Markdown.parse(text)
      names = parsed[:sections].map { |section| section[:name] }
      items = parsed[:sections].flat_map { |section| section[:items] }

      assert_operator parsed[:issue_no].to_i, :>, 0, path
      assert parsed[:title].present?, path
      # 样本里有 6 期没有「科技动态」板块，每条动态各自成为一个二级标题
      assert_includes names, "科技动态", path if text.include?("## 科技动态")
      assert_empty %w[ 文章 工具 资源 ] - names, path
      assert_empty names & %w[ 往年回顾 ], path
      assert items.size >= 5, "#{path}: #{items.size} 条"
      assert items.all? { |item| item[:title].present? }, path

      linked = items.count { |item| item[:url].present? }
      assert linked >= items.size * 0.7, "#{path}: #{linked}/#{items.size} 条有链接"
    end
  end

  test "最新期号来自 README" do
    n = Adapters::RuanyfWeekly.new(sources(:ruanyf)).latest_issue_number
    assert_equal ISSUES.map { |path| path[/issue-(\d+)/, 1].to_i }.max, n
  end

  test "fetch 返回最新期的条目，带板块与期号" do
    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch
    assert entries.size >= 5
    assert entries.all?(&:valid?)
    assert_equal (1..entries.size).to_a, entries.map(&:rank)
    assert entries.all? { |e| e.section.present? && e.meta[:issue_no].is_a?(Integer) }
    # 归一化会丢掉 fragment，回退地址只能靠 ?item= 区分，否则同期条目在 url_hash 唯一索引上撞车
    assert_equal entries.size, entries.map { |e| UrlNormalizer.url_hash(e.url) }.uniq.size
  end

  test "长条目的完整正文另行保留，不被摘要上限截断" do
    entry = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(411).find { |item| item.title == "OpenClaw 2.0 是一个缩影" }

    assert_operator entry.content.length, :>, SummaryCleaner::STORE_LIMIT
    assert_includes entry.content, "符合 AI 时代的方向"
  end

  test "配图保留清洗后段落的位置，图后的上图说明不再跑到图前" do
    entry = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(393).find { |item| item.title == "摄像头耳机" }

    assert_equal [ 1 ], entry.meta[:image_positions]
    assert_equal [ "https://cdn.beekka.com/blogimg/asset/202604/bg2026041610.webp" ], entry.meta[:image_urls]
    attrs = entry.to_item_attributes(source: sources(:ruanyf), issue: issues(:weekly_w36))
    assert_equal "上图中，耳机底部的小凸起就是微型摄像头。", attrs[:content].split("\n")[1]
  end

  test "标题之前的图片和普通行内代码不影响正文边界" do
    entry = entry_from_markdown(<<~MARKDOWN)
      1、![](https://cdn.example.com/before.webp)

      [标题](https://example.com/article)（英文）

      正文 `x_y` 和 `<T>`。

      ![](../images/after.webp)

      结尾。
    MARKDOWN

    assert_equal "标题", entry.title
    assert_equal [ 0, 1 ], entry.meta[:image_positions]
    assert_equal [ "https://cdn.example.com/before.webp", "#{RAW}/images/after.webp" ], entry.meta[:image_urls]
    assert_equal "正文 x_y 和 <T>。\n结尾。", entry.to_item_attributes(source: sources(:ruanyf), issue: issues(:weekly_w36))[:content]
    assert_includes entry.content, "`<T>`"
  end

  test "正文首行的链接并非独立标题时仍算图片前的一段" do
    entry = entry_from_markdown(<<~MARKDOWN)
      1、[欧盟](https://example.com/eu)规定，新车必须配摄像头。

      ![](https://cdn.example.com/one.webp)

      正文仍在。
    MARKDOWN

    assert_equal [ 1 ], entry.meta[:image_positions]
    assert entry.content.start_with?("[欧盟](https://example.com/eu)规定")
  end

  test "行内图片或同一行多图不生成位置，旧正文和配图仍保留" do
    [
      "正文 ![](https://cdn.example.com/one.webp) 还在。",
      "![](https://cdn.example.com/one.webp) ![](https://cdn.example.com/two.webp)"
    ].each do |line|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n#{line}\n\n正文仍在。")

      assert_nil entry.meta[:image_positions], line
      assert_includes entry.summary, "正文仍在。"
      assert_includes entry.meta[:image_urls], "https://cdn.example.com/one.webp"
    end
  end

  test "标题行含图片时保留原摘要但不推断图片位置" do
    entry = entry_from_markdown("1、[标题](https://example.com/article) ![](https://cdn.example.com/one.webp)\n\n正文仍在。")

    assert_nil entry.meta[:image_positions]
    assert_equal "正文仍在。", entry.summary
    assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
  end

  test "重复原图或绝对化后碰撞时整条保留旧图片集合而不定位" do
    [
      [ "https://cdn.example.com/one.webp", "https://cdn.example.com/one.webp", "https://cdn.example.com/one.webp" ],
      [ "../images/one.webp", "#{RAW}/images/one.webp", "#{RAW}/images/one.webp" ]
    ].each do |first, second, expected|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n![](#{first})\n\n![](#{second})")

      assert_nil entry.meta[:image_positions]
      assert_equal [ expected ], entry.meta[:image_urls]
      assert_equal "正文仍在。", SummaryCleaner.content(entry.content)
    end
  end

  test "任一图片地址非法时整条不定位，其他旧图片仍保留" do
    [ "javascript:picture", "https://[" ].each do |invalid|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n![](https://cdn.example.com/one.webp)\n\n![](#{invalid})")

      assert_nil entry.meta[:image_positions], invalid
      assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
      assert_equal "正文仍在。", SummaryCleaner.content(entry.content)
    end
  end

  test "反引号代码中的图片语法不生成位置" do
    [
      "`![](https://cdn.example.com/one.webp)`",
      "``\n![](https://cdn.example.com/one.webp)\n``",
      "```markdown\n![](https://cdn.example.com/one.webp)\n```"
    ].each do |code|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n#{code}")

      assert_nil entry.meta[:image_positions], code
      assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
      assert_includes entry.content, "正文仍在。"
    end
  end

  test "HTML 代码元素或缩进代码中的图片不生成位置" do
    [
      "<pre>\n![](https://cdn.example.com/one.webp)\n</pre>",
      "<CODE class='sample'>\n![](https://cdn.example.com/one.webp)\n</CODE>",
      "<pre>普通代码</pre>\n\n![](https://cdn.example.com/one.webp)",
      "    ![](https://cdn.example.com/one.webp)",
      "\t![](https://cdn.example.com/one.webp)",
      "  \t![](https://cdn.example.com/one.webp)"
    ].each do |code|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n#{code}")

      assert_nil entry.meta[:image_positions], code
      assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
      assert_includes entry.content, "正文仍在。"
    end
  end

  test "闭合或未闭合的 tilde 围栏内图片都不生成位置" do
    [ "~~~markdown\n![](https://cdn.example.com/one.webp)\n~~~", "~~~~\n![](https://cdn.example.com/one.webp)" ].each do |code|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n#{code}")

      assert_nil entry.meta[:image_positions], code
      assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
      assert_includes entry.content, "正文仍在。"
    end
  end

  test "HTML 注释或标签属性中的图片语法不生成位置" do
    [
      "<!--\n![](https://cdn.example.com/one.webp)\n-->",
      "<!--\n![](https://cdn.example.com/one.webp)",
      "<span data-example='\n![](https://cdn.example.com/one.webp)\n'>示例</span>"
    ].each do |html|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n#{html}")

      assert_nil entry.meta[:image_positions], html
      assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
      assert_includes entry.content, "正文仍在。"
    end
  end

  test "普通代码围栏结束后的独占行图片可以定位" do
    entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n~~~ruby\nputs 1\n~~~\n\n![](https://cdn.example.com/one.webp)\n\n结尾。")

    assert_equal [ 3 ], entry.meta[:image_positions]
  end

  test "跨图片边界清洗使前缀不同则整条不定位" do
    entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n**正文一。\n\n![](https://cdn.example.com/one.webp)\n\n正文二。**")

    assert_nil entry.meta[:image_positions]
    assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
    assert_equal "正文一。\n正文二。", SummaryCleaner.content(entry.content)
  end

  test "不能按独占行完整匹配的图片语法不返回部分位置" do
    body = "正文。\n![跨行\n替代文字](https://cdn.example.com/one.webp)\n结尾。"
    positions = Adapters::RuanyfWeekly::ImagePositions.for(
      body: body, content: "正文。\n结尾。", image_urls: [ "https://cdn.example.com/one.webp" ]
    )

    assert_nil positions
  end

  test "没有正文的专图保持旧展示而不定位" do
    entry = entry_from_markdown("![](https://cdn.example.com/one.webp)", section: "封面图")

    assert_nil entry.meta[:image_positions]
    assert_nil entry.content
    assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
  end

  test "最终正文达到安全上限时省略位置而不额外裁剪" do
    [ SummaryCleaner::CONTENT_LIMIT - 1, SummaryCleaner::CONTENT_LIMIT, SummaryCleaner::CONTENT_LIMIT + 1 ].each do |length|
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n#{'文' * length}\n\n![](https://cdn.example.com/one.webp)")

      assert_equal length, entry.content.length
      assert_equal [ "https://cdn.example.com/one.webp" ], entry.meta[:image_urls]
      if length < SummaryCleaner::CONTENT_LIMIT
        assert_equal [ 1 ], entry.meta[:image_positions]
      else
        assert_nil entry.meta[:image_positions]
      end
    end
  end

  test "最多定位 128 张图，超过时保留所有旧图片" do
    [ 128, 129 ].each do |count|
      images = count.times.map { |i| "![](https://cdn.example.com/#{i}.webp)" }.join("\n\n")
      entry = entry_from_markdown("1、[标题](https://example.com/article)\n\n正文仍在。\n\n#{images}")

      assert_equal count, entry.meta[:image_urls].size
      assert_equal "正文仍在。", SummaryCleaner.content(entry.content)
      if count == 128
        assert_equal [ 1 ] * count, entry.meta[:image_positions]
      else
        assert_nil entry.meta[:image_positions]
      end
    end
  end

  test "条目少于 5 条降级" do
    stub_request(:get, "#{RAW}/docs/issue-999.md").to_return(body: "# 科技爱好者周刊（第 999 期）：坏了\n\n## 科技动态\n\n1、只有一条 [x](https://a.b)\n")
    error = assert_raises(Adapters::RuanyfWeekly::Degraded) { Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(999) }
    assert_equal 999, error.issue_no
    assert_equal "坏了", error.issue_title
    assert_equal "https://github.com/ruanyf/weekly/blob/master/docs/issue-999.md", error.url
  end

  test "相对链接解析为绝对地址" do
    stub_request(:get, "#{RAW}/docs/issue-998.md").to_return(body: <<~MARKDOWN)
      # 科技爱好者周刊（第 998 期）：相对链接

      ## 科技动态

      1、[去年的合刊](../docs/issue-900.md)

      正文一。

      2、[第二条](https://b.example/2)

      正文二。

      3、[第三条](https://c.example/3)

      正文三。

      4、[第四条](https://d.example/4)

      正文四。

      5、[第五条](https://e.example/5)

      正文五。
    MARKDOWN

    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(998)
    assert_equal 5, entries.size
    assert entries.first.url.start_with?("https://github.com/ruanyf/weekly/blob/master/"), entries.first.url
    assert entries.all?(&:valid?)
  end

  test "图片板块条目链接指向原文锚点" do
    stub_request(:get, "#{RAW}/docs/issue-997.md").to_return(body: <<~MARKDOWN)
      # 科技爱好者周刊（第 997 期）：图片测试

      ## 科技动态

      1、[第一条](https://example.com/1)

      正文一。

      2、[第二条](https://example.com/2)

      正文二。

      3、[第三条](https://example.com/3)

      正文三。

      4、[第四条](https://example.com/4)

      正文四。

      5、[第五条](https://example.com/5)

      正文五。

      ## 图片

      1、**一张图**

      [来源](https://example.com/source)
    MARKDOWN

    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(997)
    image_entry = entries.find { |e| e.section == "图片" }

    assert image_entry.present?, "Should have an entry in 图片 section"
    assert_equal "https://github.com/ruanyf/weekly/blob/master/docs/issue-997.md?item=6#%E5%9B%BE%E7%89%87", image_entry.url
    assert_not_equal "https://example.com/source", image_entry.url
    assert entries.all?(&:valid?)
  end

  test "图片按条目归属并把相对地址转换为可展示的绝对地址" do
    stub_request(:get, "#{RAW}/docs/issue-993.md").to_return(body: <<~MARKDOWN)
      # 科技爱好者周刊（第 993 期）：图片归属

      ## 封面图

      ![](https://cdn.example.com/cover.webp)

      封面图注。

      ## 科技动态

      1、[第一条](https://example.com/1)

      ![第一张](https://cdn.example.com/one.webp)

      ![第二张](../images/two.webp)

      正文一。

      2、[第二条](https://example.com/2)

      ![](javascript:alert(1))

      正文二。

      3、[第三条](https://example.com/3)

      正文三。

      4、[第四条](https://example.com/4)

      正文四。

      5、[第五条](https://example.com/5)

      正文五。
    MARKDOWN

    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(993)
    cover = entries.find { |entry| entry.section == "封面图" }
    first = entries.find { |entry| entry.title == "第一条" }
    second = entries.find { |entry| entry.title == "第二条" }

    assert_equal [ "https://cdn.example.com/cover.webp" ], cover.meta[:image_urls]
    assert_equal [ 0 ], cover.meta[:image_positions]
    assert_equal [ "https://cdn.example.com/one.webp", "#{RAW}/images/two.webp" ], first.meta[:image_urls]
    assert_equal [ 0, 0 ], first.meta[:image_positions]
    assert_nil second.meta[:image_urls]
    assert_nil second.meta[:image_positions]
    assert_not_includes first.summary, "!["
  end

  test "专题与封面板块整体成为一条，往年回顾不出条目" do
    stub_request(:get, "#{RAW}/docs/issue-996.md").to_return(body: <<~MARKDOWN)
      # 科技爱好者周刊（第 996 期）：专题测试

      这里记录每周值得分享的科技内容，周五发布。

      ## 封面图

      ![](https://cdn.example.com/cover.webp)

      封面图注不该成为条目。

      ## rsync 的争论

      本周，[rsync](https://example.com/rsync) 的维护者引发了争论。

      ![](https://cdn.example.com/1.webp)

      （1）有人说不该用 AI。

      （2）也有人表示理解。

      结论是没有结论。

      ## 科技动态

      1、[第一条](https://example.com/1)

      正文一。

      2、[第二条](https://example.com/2)

      正文二。

      3、[第三条](https://example.com/3)

      正文三。

      4、[第四条](https://example.com/4)

      正文四。

      ## 往年回顾

      - [去年的这个时候](https://example.com/old)
    MARKDOWN

    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(996)
    cover = entries.first
    essay = entries.second

    assert_equal [ "封面图", "rsync 的争论", "科技动态" ], entries.map(&:section).uniq
    assert_equal [ "https://cdn.example.com/cover.webp" ], cover.meta[:image_urls]
    assert_equal [ 0 ], cover.meta[:image_positions]
    assert_equal [ 1 ], essay.meta[:image_positions]
    assert_equal 1, entries.count { |e| e.section == "rsync 的争论" }
    assert_equal "rsync 的争论", essay.title
    assert_equal "https://example.com/rsync", essay.url
    assert_includes essay.summary, "（1）有人说不该用 AI。"
    assert_includes essay.summary, "结论是没有结论。"
    assert_not_includes essay.summary, "![]"
    assert_equal "rsync-的争论", essay.meta[:anchor]
    assert entries.all?(&:valid?)
  end

  test "首行是标题加括注时摘要不重复标题，正文开头的链接照旧保留" do
    parsed = Adapters::RuanyfWeekly::Markdown.parse(<<~MARKDOWN)
      # 科技爱好者周刊（第 994 期）：摘要测试

      ## 文章

      1、[为什么前端很难](https://example.com/a)（英文）

      作者认为，浏览器的兼容性是罪魁祸首。

      ## 科技动态

      1、[欧盟](https://example.com/eu)规定，今年7月7日起，新车必须配摄像头。

      这条规定引发了争议。
    MARKDOWN

    article = parsed[:sections].first[:items].sole
    news = parsed[:sections].last[:items].sole

    assert_equal "为什么前端很难", article[:title]
    assert_equal "作者认为，浏览器的兼容性是罪魁祸首。", article[:summary]
    assert_equal "欧盟", news[:title]
    assert news[:summary].start_with?("[欧盟](https://example.com/eu)规定"), news[:summary]
  end

  test "同一板块里无链接的条目回退地址各不相同" do
    stub_request(:get, "#{RAW}/docs/issue-995.md").to_return(body: <<~MARKDOWN)
      # 科技爱好者周刊（第 995 期）：回退地址

      ## 科技动态

      1、[第一条](https://example.com/1)

      正文一。

      2、[第二条](https://example.com/2)

      正文二。

      3、[第三条](https://example.com/3)

      正文三。

      ## 言论

      1、

      第一句话，没有出处链接。

      2、

      第二句话，也没有出处链接。
    MARKDOWN

    entries = Adapters::RuanyfWeekly.new(sources(:ruanyf)).fetch_issue(995)
    quotes = entries.select { |e| e.section == "言论" }

    assert_equal 2, quotes.size
    assert quotes.all? { |e| e.url.include?("?item=") }, quotes.map(&:url).inspect
    assert_equal 2, quotes.map { |e| UrlNormalizer.url_hash(e.url) }.uniq.size
    assert entries.all?(&:valid?)
  end

  test "一句话消息按列表拆条" do
    text = file_fixture("ruanyf/issue-401.md").read
    parsed = Adapters::RuanyfWeekly::Markdown.parse(text)
    section = parsed[:sections].find { |s| s[:name].include?("一句话消息") }

    assert section.present?, "Should have 一句话消息 section"
    assert_operator section[:items].size, :>=, 3, "一句话消息 should have at least 3 items"
    assert section[:items].all? { |item| item[:title].present? }, "All items should have titles"
  end

  private
    def entry_from_markdown(body, section: "科技动态")
      markdown = "# 科技爱好者周刊（第 990 期）：图片位置\n\n## #{section}\n\n#{body}\n"
      stub_request(:get, "#{RAW}/docs/issue-990.md").to_return(body: markdown)
      source = sources(:ruanyf).dup
      source.config = { min_items: 1 }
      Adapters::RuanyfWeekly.new(source).fetch_issue(990).sole
    end
end
