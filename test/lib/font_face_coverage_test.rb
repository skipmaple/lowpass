require "test_helper"
require "set"

class FontFaceCoverageTest < ActiveSupport::TestCase
  test "正文字体精简保留每个分片的原范围与界面字失败回退" do
    original = faces(Rails.root.join("node_modules/lxgw-wenkai-screen-webfont/lxgwwenkaiscreen.css"))
    current = faces(Rails.root.join("app/frontend/styles/fonts-content.css"))
    assert_equal original.map { |face| face[:file] }, current.map { |face| face[:file] }
    all_original = original.reduce(Set.new) { |points, face| points | face[:points] }

    original.zip(current).each do |before, after|
      assert_empty before[:points] - after[:points], "#{before[:file]} 不能删除已有字的回退"
      extra = after[:points] - before[:points]
      assert_empty extra & all_original, "不能改变已声明字符的分片选择"
      extra.each do |point|
        assert (0x3400..0x9fff).cover?(point), "仅桥接汉字区的缺字洞"
        assert before[:points].include?(point - 1) && before[:points].include?(point + 1), "仅合并单一码位空洞"
      end
    end
  end

  private
    def faces(path)
      File.read(path).scan(/@font-face\s*\{([^}]+)\}/m).map do |block,|
        url = block[/url\(["']?([^"')]+)["']?\)/, 1]
        points = block[/unicode-range:\s*([^;}]+)/, 1].split(",").flat_map do |range|
          first, last = range.strip.delete_prefix("U+").split("-").map { |hex| hex.to_i(16) }
          (first..(last || first)).to_a
        end.to_set
        { file: File.basename(url), points: points }
      end
    end
end
