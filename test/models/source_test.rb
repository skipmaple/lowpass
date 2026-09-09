require "test_helper"

class SourceTest < ActiveSupport::TestCase
  test "enabled.daily.ordered 按 sort_order 返回三个日刊源，排除周刊源" do
    assert_equal [ sources(:hn), sources(:github), sources(:hackaday) ], Source.enabled.daily.ordered.to_a
  end

  test "adapter 不在白名单内则无效" do
    source = Source.new(name: "Unknown Source", adapter: "unknown", publication: "daily")
    assert_not source.valid?
  end
end
