require "test_helper"

class Issue::ImageDimensionsPresentingTest < ActiveSupport::TestCase
  test "周刊合并独立尺寸缓存，已发布条目与期的字段保持不变" do
    url = "https://cdn.example.com/cover.png"
    issue = issues(:weekly_w36)
    item = items(:hn_one).dup
    item.update!(issue: issue, source: sources(:ruanyf), meta: { image_urls: [ url ] })
    ImageDimension.create!(url: url, url_hash: Digest::SHA256.hexdigest(url), width: 1200, height: 800, confirmed_at: Time.current)
    rows = nil

    assert_no_changes -> { [ item.reload.attributes, issue.reload.attributes ] } do
      rows = issue.weekly_section_props.flat_map { |section| section[:groups].flat_map { |group| group[:items] } }
    end

    row = rows.find { |props| props[:id] == item.id }
    assert_equal({ url => { width: 1200, height: 800 } }, row[:image_dimensions])
    assert_equal({ "image_urls" => [ url ] }, item.reload.meta)
    assert_not item.meta.key?("image_dimensions")
  end
end
