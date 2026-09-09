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
      assert_empty names & %w[ 封面图 往年回顾 ], path
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
    assert_equal entries.size, entries.map { |e| UrlNormalizer.hash(e.url) }.uniq.size
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

  test "专题板块整体成为一条，封面图与往年回顾不出条目" do
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
    essay = entries.first

    assert_equal [ "rsync 的争论", "科技动态" ], entries.map(&:section).uniq
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
    assert_equal 2, quotes.map { |e| UrlNormalizer.hash(e.url) }.uniq.size
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
end
