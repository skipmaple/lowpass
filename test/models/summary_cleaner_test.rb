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
end
