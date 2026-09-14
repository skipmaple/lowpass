require "test_helper"

class ModelCallTest < ActiveSupport::TestCase
  test "状态只认四种；保留 90 天" do
    call = ModelCall.new(issue: issues(:daily_0908), item: items(:hn_one), status: "nope")
    assert_not call.valid?

    ModelCall.create!(issue: issues(:daily_0908), item: items(:hn_one), status: "ok", prompt_tokens: 10, completion_tokens: 5, cost: 0.001, created_at: 91.days.ago)
    keep = ModelCall.create!(issue: issues(:daily_0908), item: items(:hn_one), status: "failed", error_summary: "500", created_at: 89.days.ago)
    ModelCall.cleanup
    assert_equal [ keep ], ModelCall.all.to_a
  end
end
