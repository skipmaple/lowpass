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

      assert parsed[:issue_no] > 0, path
      assert parsed[:title].present?, path
      # 样本里有 6 期没有「科技动态」板块，每条动态各自成为一个二级标题
      assert_includes names, "科技动态", path if text.include?("## 科技动态")
      assert_empty %w[ 文章 工具 资源 ] - names, path
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
    assert image_entry.url.start_with?("https://github.com/ruanyf/weekly/blob/master/docs/issue-997.md#"), image_entry.url
    assert_not_equal "https://example.com/source", image_entry.url
    assert entries.all?(&:valid?)
  end
end
