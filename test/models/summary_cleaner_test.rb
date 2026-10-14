require "test_helper"

class SummaryCleanerTest < ActiveSupport::TestCase
  test "去标签、解实体、合并空白、截断" do
    assert_equal "Hello & world", SummaryCleaner.clean("<p>Hello &amp;\n\n  <b>world</b></p>")
    long = SummaryCleaner.clean("字" * 600)
    assert_equal 500, long.length
    assert long.end_with?("…")
  end

  test "去 Markdown 标记" do
    assert_equal "标题 链接 加粗", SummaryCleaner.clean("## 标题 [链接](https://x.y) **加粗**")
    assert_equal "斜体 强调 代码", SummaryCleaner.clean("*斜体* _强调_ `代码`")
  end

  # 仓库名与标识符里的下划线、星号是内容，不是排版：GitHub Trending 一栏全是这种名字
  test "词里的下划线与星号留着" do
    assert_equal "snake_case 与 some_repo_name 都要留着", SummaryCleaner.clean("snake_case 与 some_repo_name 都要留着")
    assert_equal "a*b 与 x_y 也是", SummaryCleaner.clean("a*b 与 x_y 也是")
  end

  # 周刊正文（D24）要分段：原文一行一段（段间空行、图片行都不算段），段内空白照旧压平
  test "完整正文留住分段" do
    markdown = "本周，OpenClaw 发布了[2.0版](https://openclaw.ai)。\n\n![](https://cdn.example/a.webp)\n\n是不是很久没听到这个名字了？\n\n- 第一点  很重要\n- **第二点**"
    assert_equal "本周，OpenClaw 发布了2.0版。\n是不是很久没听到这个名字了？\n第一点 很重要\n第二点", SummaryCleaner.content(markdown)
    assert_equal "本周，OpenClaw 发布了2.0版。 是不是很久没听到这个名字了？ 第一点 很重要 第二点", SummaryCleaner.clean(markdown)
  end

  test "列表预览 200 字" do
    assert_equal 200, SummaryCleaner.preview("字" * 300).length
  end

  # Hackaday 的 RSS 摘要末尾带一个 class="read-more" 的链接，文字是「…read more」：那是源站的导航，不是摘要（PRD 7.5）
  test "去掉源站附加的阅读更多链接" do
    html = %(<div><img src="x.jpg"></div>The progression of the web browser. Today <a href="https://hackaday.com/x/" class="read-more">&#8230;read more</a>)
    assert_equal "The progression of the web browser. Today", SummaryCleaner.clean(html)
    assert_equal "Keep going", SummaryCleaner.clean(%(Keep going <a class="more-link" href="/x">Continue reading</a>))
  end

  # 已发布的旧条目库里存着清洗过的「…read more」；页面数据会再过一遍 clean，只去结尾这一种，正文里的不动
  test "已存摘要结尾的…read more 去掉，别处的不动" do
    assert_equal "so too does the", SummaryCleaner.clean("so too does the …read more")
    assert_equal "Today", SummaryCleaner.clean("Today …Read More ")
    assert_equal "Why you should read more books", SummaryCleaner.clean("Why you should read more books")
    assert_equal "…read more in the middle stays", SummaryCleaner.clean("…read more in the middle stays")
  end

  test "Hackaday 样本的摘要都不带阅读更多" do
    xml = Nokogiri::XML(file_fixture("rss/hackaday.xml").read)
    summaries = xml.xpath("//item/description").map { |node| SummaryCleaner.clean(node.text) }

    assert_equal 7, summaries.size
    assert summaries.none? { |summary| summary.match?(/read more/i) }, summaries.grep(/read more/i).inspect
  end
end
