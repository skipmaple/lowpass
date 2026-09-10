require "test_helper"

# 高亮与片段（R-4.6、设计 5.5）：拉丁词按词首前缀不分大小写，中文按子串；片段围绕首个命中
class Search::HighlighterTest < ActiveSupport::TestCase
  def highlighter(q) = Search::Highlighter.new(Search::Query.parse(q: q).terms)
  def pairs(runs) = runs.map { |run| [ run[:text], run[:hit] ] }
  def joined(runs) = runs.map { |run| run[:text] }.join

  test "拉丁词按词首前缀标出，不分大小写，只标前缀相同的部分" do
    assert_equal [ [ "Kuber", true ], [ "netes operator in ", false ], [ "Rust", true ] ],
                 pairs(highlighter("kuber rust").runs("Kubernetes operator in Rust"))
  end

  test "词中间不算命中；拼错的词不标" do
    assert_equal [ [ "Kubernetes", false ] ], pairs(highlighter("ube").runs("Kubernetes"))
    assert_equal [ [ "Kubernetes", false ] ], pairs(highlighter("kubernets").runs("Kubernetes"))
  end

  test "中文按子串标出，重叠的二元组合并成一段" do
    assert_equal [ [ "一个", false ], [ "终端", true ], [ "下的日志", false ], [ "工具", true ] ],
                 pairs(highlighter("终端 工具").runs("一个终端下的日志工具"))
    assert_equal [ [ "终端工", true ], [ "具", false ] ], pairs(highlighter("终端工").runs("终端工具"))
  end

  test "没有命中时整段是一个 run；空文本没有 run；片段为空返回 nil" do
    assert_equal [ [ "Nothing here", false ] ], pairs(highlighter("rust").runs("Nothing here"))
    assert_equal [], highlighter("rust").runs("")
    assert_nil highlighter("rust").snippet(nil)
    assert_nil highlighter("rust").snippet("")
  end

  test "短文本不截断，整段给回" do
    assert_equal [ [ "A ", false ], [ "terminal", true ], [ " log viewer", false ] ], pairs(highlighter("terminal").snippet("A terminal log viewer"))
  end

  test "片段围绕首个命中：向前留约 40 字，不从词中间开始，总长不超过 160，两端加省略号" do
    text = (1..30).map { |i| "w#{i}" }.join(" ") + " terminal log " + ("z " * 120)
    runs = highlighter("terminal").snippet(text)
    body = joined(runs)

    assert_operator body.length, :<=, 160
    assert body.start_with?("…")
    assert body.end_with?("…")
    assert_match(/\A…w\d+ /, body)
    assert_operator body.index("terminal"), :<=, 41
    assert_operator body.index("terminal"), :>=, 30
    assert_includes pairs(runs), [ "terminal", true ]
  end

  test "没有命中的片段取前 158 字加省略号" do
    text = "x " * 200
    body = joined(highlighter("rust").snippet(text))

    assert_equal 159, body.length
    assert body.end_with?("…")
    assert_equal text[0, 158], body[0, 158]
  end

  test "中文片段按字符截，两端不受词边界规则影响" do
    text = "前" * 100 + "终端" + "后" * 100
    body = joined(highlighter("终端").snippet(text))

    assert_operator body.length, :<=, 160
    assert_equal 41, body.index("终端")
    assert body.start_with?("…")
  end

  # 连续不断的长字符串（地址、仓库名）不能把预算吃掉：最多为了词边界挪 20 字，再长就照切
  test "命中后面跟着超长字符串时片段仍用满预算" do
    body = joined(highlighter("rust").snippet("Rust " + "z" * 300))

    assert body.start_with?("Rust ")
    assert body.end_with?("…")
    assert_operator body.length, :>=, 150
    assert_operator body.length, :<=, 160
  end

  test "命中前面是超长字符串时仍留约 40 字的前文" do
    body = joined(highlighter("terminal").snippet("y" * 200 + " terminal " + "k" * 5))

    assert body.start_with?("…")
    assert_equal 41, body.index("terminal")
    assert body.end_with?("terminal kkkkk")
  end

  test "没有命中且开头是超长字符串时仍取前 158 字" do
    body = joined(highlighter("rust").snippet("ab " + "q" * 300))

    assert_equal 159, body.length
    assert body.end_with?("…")
  end

  test "边界内的短词仍然不被切开" do
    text = (1..30).map { |i| "w#{i}" }.join(" ") + " terminal log " + ("z " * 120)
    body = joined(highlighter("terminal").snippet(text))

    assert_match(/\A…w\d+ /, body)
    assert_match(/ z…\z|z…\z/, body)
  end
end
