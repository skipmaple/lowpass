# 命中高亮与摘要片段（R-4.6、设计 5.5）。判定与 Runner 的匹配规则对齐但在 Ruby 里做：拉丁词按词首
# 不分大小写的前缀（拼写容错命中的词只标前缀相同的部分，拼错的整词不标，接受这一简化），中文词按子串。
# 输出是 run 序列 [{ text:, hit: }]，前端给 hit 的 run 画 2px 墨色下划线（D22）。在 items 原文上做：
# 原文含全角字母的极少数情况不高亮（接受）。
class Search::Highlighter
  LEAD = 40    # 首个命中前留的字数
  BODY = 158   # 片段正文上限：两端各加一个「…」正好 160（R-4.6「片段不超过 160 字」）
  SLACK = 20   # 为了不切在词中间最多挪这么多字：再长的连续字符串（地址、仓库名）就照切，预算不能让给它
  LATIN = /[\p{L}\p{N}]/
  CJK_CHAR = "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]"

  def initialize(terms)
    @patterns = terms.map { |term| pattern(term) }
  end

  def runs(text)
    return [] if text.blank?

    mask = Array.new(text.length, false)
    @patterns.each do |pattern|
      text.to_enum(:scan, pattern).each { mask.fill(true, Regexp.last_match.begin(0), Regexp.last_match[0].length) }
    end
    text.each_char.zip(mask).chunk_while { |(_, a), (_, b)| a == b }.map { |chunk| { text: chunk.map(&:first).join, hit: chunk.first.last } }
  end

  # 找第一个命中的位置，向前留约 40 字、总长不超过 160 字，两端不在拉丁词中间截断，截断处加「…」；
  # 没有命中就取开头
  def snippet(text)
    return nil if text.blank?

    first = first_hit(text)
    start = word_start(text, first ? [ first - LEAD, 0 ].max : 0, first)
    finish = word_end(text, start, [ start + BODY, text.length ].min, first)
    runs("#{"…" if start > 0}#{text[start...finish]}#{"…" if finish < text.length}")
  end

  private
    def pattern(term)
      if term.cjk?
        /#{Regexp.escape(term.text)}/
      else
        # 词首：前面不是字母数字，或者前面是汉字（「用Rust写的」的 Rust 也算词首，与索引副本补空格的规则一致）
        /(?:(?<![\p{L}\p{N}\p{M}])|(?<=#{CJK_CHAR}))#{Regexp.escape(term.text)}/i
      end
    end

    def first_hit(text)
      @patterns.filter_map { |pattern| text.index(pattern) }.min
    end

    # 起点落在拉丁词中间就往后挪到下一个空格之后（不越过命中，最多挪 SLACK 字）
    def word_start(text, start, first)
      return start if start.zero? || !latin_boundary?(text, start)

      gap = text.index(/\s/, start)
      gap && first && gap < first && gap - start <= SLACK ? gap + 1 : start
    end

    # 终点落在拉丁词中间就往前退到上一个空格（不退进命中里，最多退 SLACK 字）
    def word_end(text, start, finish, first)
      return finish if finish >= text.length || !latin_boundary?(text, finish)

      gap = text.rindex(/\s/, finish)
      gap && gap > (first || start) + 1 && finish - gap <= SLACK ? gap : finish
    end

    # 位置两侧都是拉丁字母数字：切在这里就是切在词中间
    def latin_boundary?(text, at)
      [ text[at - 1], text[at] ].all? { |char| char&.match?(LATIN) && !char.match?(Search::Query::CJK) }
    end
end
