require "test_helper"

class Reasons::StatusTest < ActiveSupport::TestCase
  test "没配：configured 假、数字都是 0；配了：带地址与用量" do
    props = Reasons::Status.props
    assert_equal false, props[:configured]
    assert_equal false, props[:key_configured]
    assert_equal "", props[:base_url]
    assert_equal "0.0", props[:month_cost]
    assert_equal 0, props[:today_calls]

    with_model_provider do
      Setting.set("model_input_price", "2")
      Setting.set("model_monthly_cap", "50")
      ModelCall.create!(status: "ok", cost: 1.25)
      props = Reasons::Status.props
      assert props[:configured]
      assert props[:key_configured]
      assert_equal "https://model.example/v1", props[:base_url]
      assert_equal "test-model", props[:model_name]
      assert_equal "2", props[:input_price]
      assert_equal "50", props[:monthly_cap]
      assert_equal 1, props[:month_calls]
      assert_equal "1.25", props[:month_cost]
    end
  end
end
