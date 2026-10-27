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

  test "汉字旁成对的强调标记转成纯文本" do
    markdown = "改成**每月发一个版本**。把*斜体*接着写。"

    assert_equal "改成每月发一个版本。把斜体接着写。", SummaryCleaner.clean(markdown)
  end

  # 仓库名与标识符里的下划线、星号是内容，不是排版：GitHub Trending 一栏全是这种名字
  test "词里的下划线与星号留着" do
    assert_equal "snake_case 与 some_repo_name 都要留着", SummaryCleaner.clean("snake_case 与 some_repo_name 都要留着")
    assert_equal "a*b 与 x_y 也是", SummaryCleaner.clean("a*b 与 x_y 也是")
    assert_equal "in**line**word some__repo__name in*line*word résumé__value__name", SummaryCleaner.clean("in**line**word some__repo__name in*line*word résumé__value__name")
  end

  test "汉字标识符里的下划线留着" do
    assert_equal "变量_用户_名称与变量__用户__名称", SummaryCleaner.clean("变量_用户_名称与变量__用户__名称")
  end

  test "反引号码片段里的下划线和星号留着" do
    assert_equal "代码是变量_用户_名称。", SummaryCleaner.content("代码是`变量_用户_名称`。")
    assert_equal "写作目录**/文件.rb，配合目录**/文件.ts使用。", SummaryCleaner.content("写作`目录**/文件.rb`，配合`目录**/文件.ts`使用。")
    assert_equal "写作目录**/`文件.rb，配合目录**/文件.ts使用。", SummaryCleaner.content("写作``目录**/`文件.rb``，配合`目录**/文件.ts`使用。")
  end

  test "反引号码片段里的标签与链接是内容" do
    assert_equal "写作<section>与[name](https://example.com)。", SummaryCleaner.content("写作`<section>`与`[name](https://example.com)`。")
  end

  test "强调跨过代码片段时只清理外层排版" do
    assert_equal "使用变量_用户_名称说明。", SummaryCleaner.content("**使用`变量_用户_名称`说明**。")
  end

  test "HTML code 和 pre 中的代码符号留着" do
    html = "<p>写作<code>目录**/文件.rb</code>，配合<code>目录**/文件.ts</code>使用。</p>"
    assert_equal "写作目录**/文件.rb，配合目录**/文件.ts使用。", SummaryCleaner.clean(html)
    assert_equal "写作目录**/文件.rb，配合目录**/文件.ts使用。", SummaryCleaner.content(html)
    assert_equal "变量_用户_名称\n目录**/文件.rb、目录**/文件.ts", SummaryCleaner.content("<pre>变量_用户_名称\n目录**/文件.rb、目录**/文件.ts</pre>")
  end

  test "嵌套的 HTML code 与 pre 只按 HTML 语义解码一次" do
    html = "<pre><code>&amp;lt;T&amp;gt; &lt;em&gt; &amp;#42; `x_y`</code></pre>"

    assert_equal "&lt;T&gt; <em> &#42; `x_y`", SummaryCleaner.content(html)
  end

  test "不同 HTML code 节点里的反引号不配对" do
    html = "<p>第一段写<code>`</code>，第二段写<code>`</code>。</p>"

    assert_equal "第一段写`，第二段写`。", SummaryCleaner.clean(html)
  end

  test "HTML 属性里的反引号与大于号不作为 Markdown 代码" do
    html = %(<p data-note="` > x">第一段</p><p data-note="`">第二段</p>)

    assert_equal "第一段第二段", SummaryCleaner.clean(html)
  end

  test "不同 HTML 段落里的独立反引号不配对" do
    html = "<p>按下 ` 键。</p><p>再次按下 ` 键。</p>"

    assert_equal "按下 ` 键。再次按下 ` 键。", SummaryCleaner.clean(html)
  end

  test "同一 HTML 段落里的反引号也不跨 span 节点配对" do
    html = "<p><span>按下 ` 键。</span><span>再次按下 ` 键。</span></p>"

    assert_equal "按下 ` 键。再次按下 ` 键。", SummaryCleaner.clean(html)
  end

  test "HTML 结束与 void 标签之后恢复原始 Markdown 代码语义" do
    assert_equal "正文写作<section>。", SummaryCleaner.clean("<p>正文</p>写作`<section>`。")
    assert_equal "写作<T>。", SummaryCleaner.clean(%(<img src="/x.png">写作`<T>`。))
  end

  test "HTML 文字节点中的 Markdown 代码按 HTML 语义解实体一次" do
    html = "<p>写作`&amp;lt;T&amp;gt;`与`&lt;T&gt;`。</p>"

    assert_equal "写作&lt;T&gt;与<T>。", SummaryCleaner.clean(html)
  end

  test "HTML 代码保护保留阅读更多链接的清理" do
    html = %(<p>写作<code>目录**/文件.rb</code>，配合<code>目录**/文件.ts</code>使用。</p><a class="read-more" href="/x">…read more</a>)

    assert_equal "写作目录**/文件.rb，配合目录**/文件.ts使用。", SummaryCleaner.clean(html)
  end

  test "不成对或两端数量不同的强调标记留着" do
    assert_equal "改成**每月发一个版本。", SummaryCleaner.clean("改成**每月发一个版本。")
    assert_equal "改成**每月发一个版本*。", SummaryCleaner.clean("改成**每月发一个版本*。")
    assert_equal "改成*每月发一个版本**。", SummaryCleaner.clean("改成*每月发一个版本**。")
    assert_equal "将__重点_保留。", SummaryCleaner.clean("将__重点_保留。")
    assert_equal "将_重点__保留。", SummaryCleaner.clean("将_重点__保留。")
  end

  # 周刊正文（D24）要分段：原文一行一段（段间空行、图片行都不算段），段内空白照旧压平
  test "完整正文留住分段" do
    markdown = "本周，OpenClaw 发布了[2.0版](https://openclaw.ai)。\n\n![](https://cdn.example/a.webp)\n\n是不是很久没听到这个名字了？\n\n- 第一点  很重要\n- **第二点**"
    assert_equal "本周，OpenClaw 发布了2.0版。\n是不是很久没听到这个名字了？\n第一点 很重要\n第二点", SummaryCleaner.content(markdown)
    assert_equal "本周，OpenClaw 发布了2.0版。 是不是很久没听到这个名字了？ 第一点 很重要 第二点", SummaryCleaner.clean(markdown)
  end

  test "完整正文在清洗强调后仍保留安全上限内的所有段落" do
    markdown = "改成**每月发一个版本**。\n\n" + "字" * 600
    assert_equal "改成每月发一个版本。\n" + "字" * 600, SummaryCleaner.content(markdown)

    limit = "字" * 50_000
    assert_equal limit, SummaryCleaner.content(limit)
    assert_equal "字" * 49_999 + "…", SummaryCleaner.content(limit + "字")
  end

  test "列表预览 200 字" do
    assert_equal 200, SummaryCleaner.preview("字" * 300).length
  end

  test "源站明确标记截断的摘要保留省略号但不保留阅读更多" do
    html = %(Learning a new language can be difficult <a class="read-more" href="/x">&#8230;read more</a>)

    assert_equal "Learning a new language can be difficult …", SummaryCleaner.clean(html)
    assert_equal "已存的未完成摘要…", SummaryCleaner.stored("已存的未完成摘要 …read more")
    assert_equal "内容完整。", SummaryCleaner.clean(%(内容完整。<a class="more-link" href="/x">Continue reading</a>))
    assert_equal "内容完整。", SummaryCleaner.clean(%(内容完整。<a class="read-more" href="/x">…read more</a>))
    assert_equal "内容完整。", SummaryCleaner.stored("内容完整。 …read more")
    assert_equal "", SummaryCleaner.clean(%(<a class="read-more" href="/x">…read more</a>))
  end

  test "正文中途的阅读更多不添加截断标记，完整正文保持原有清洗" do
    html = %(<p>Alpha <a class="read-more">…read more</a></p><p>Beta continues.</p>)

    assert_equal "Alpha Beta continues.", SummaryCleaner.clean(html)
    assert_equal "Alpha Beta continues.", SummaryCleaner.content(html)
    assert_equal "OneTwo…", SummaryCleaner.clean(%(One<a class="read-more">…read more</a>Two<a class="read-more">…read more</a>))
  end

  test "代码片段中的句末标点也能识别为完整句子" do
    html = %(A complete <code>sentence.</code><a class="read-more">…read more</a>)

    assert_equal "A complete sentence.", SummaryCleaner.clean(html)
  end

  test "Markdown 句末标点和不会显示的图片不误导截断判断" do
    [ "**This is complete.**", "*Complete sentence!*", "[Complete sentence.](https://example.com)" ].each do |text|
      html = %(#{text} <a class="read-more">…read more</a>)
      assert_not SummaryCleaner.clean(html).end_with?("…"), text
    end

    assert_equal "", SummaryCleaner.clean(%(![leading](https://example.com/a.png) <a class="read-more">…read more</a>))
    assert_equal "Partial …", SummaryCleaner.clean(%(Partial <a class="read-more">…read more</a> ![image](https://example.com/a.png)))
  end

  # Hackaday 的导航文字移除，源站明确的未完标记保留（PRD 7.5）。
  test "去掉阅读更多链接并保留源站的截断标记" do
    html = %(<div><img src="x.jpg"></div>The progression of the web browser. Today <a href="https://hackaday.com/x/" class="read-more">&#8230;read more</a>)
    assert_equal "The progression of the web browser. Today …", SummaryCleaner.clean(html)
    assert_equal "Keep going", SummaryCleaner.clean(%(Keep going <a class="more-link" href="/x">Continue reading</a>))
  end

  # 已发布的旧条目如果还留有这一尾巴，展示时保留它明确指示的未完状态。
  test "已存摘要结尾的阅读更多去掉，省略号保留，别处的不动" do
    assert_equal "so too does the…", SummaryCleaner.clean("so too does the …read more")
    assert_equal "Today…", SummaryCleaner.clean("Today …Read More ")
    assert_equal "Why you should read more books", SummaryCleaner.clean("Why you should read more books")
    assert_equal "…read more in the middle stays", SummaryCleaner.clean("…read more in the middle stays")
  end

  test "已存摘要只去阅读更多尾巴，保留其余文字与空白" do
    text = " **原文**\n变量_用户_名称，目录**/文件.rb、目录**/文件.ts，<T> 与 &lt;value&gt;。"

    assert_equal text, SummaryCleaner.stored(text)
    assert_equal text, SummaryCleaner.stored(text + " …Read More ")
    assert_equal "…read more in the middle stays", SummaryCleaner.stored("…read more in the middle stays")
    assert_nil SummaryCleaner.stored(nil)
  end

  test "Hackaday 样本的摘要都不带阅读更多" do
    xml = Nokogiri::XML(file_fixture("rss/hackaday.xml").read)
    summaries = xml.xpath("//item/description").map { |node| SummaryCleaner.clean(node.text) }

    assert_equal 7, summaries.size
    assert summaries.none? { |summary| summary.match?(/read more/i) }, summaries.grep(/read more/i).inspect
  end
end
