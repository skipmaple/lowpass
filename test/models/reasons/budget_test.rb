require "test_helper"

class Reasons::BudgetTest < ActiveSupport::TestCase
  def sh(str) = Time.find_zone("Asia/Shanghai").parse(str)

  test "费用按每百万 token 的单价算，四位小数" do
    Setting.set("model_input_price", "2")
    Setting.set("model_output_price", "8")
    assert_equal BigDecimal("0.0026"), Reasons::Budget.cost_for(500, 200)
    assert_equal BigDecimal("0"), Reasons::Budget.cost_for(0, 0)
  end

  test "上限 0 不拦；到上限拦；月按上海时区" do
    travel_to sh("2026-09-14 10:00") do
      ModelCall.create!(status: "ok", cost: 3, created_at: sh("2026-09-01 00:30"))
      ModelCall.create!(status: "ok", cost: 5, created_at: sh("2026-08-31 23:30"))
      assert_equal BigDecimal("3"), Reasons::Budget.month_cost
      assert_equal 1, Reasons::Budget.month_calls
      assert_not Reasons::Budget.exhausted?

      Setting.set("model_monthly_cap", "3")
      assert Reasons::Budget.exhausted?
      Setting.set("model_monthly_cap", "3.5")
      assert_not Reasons::Budget.exhausted?
    end
  end

  test "今日调用按上海自然日" do
    travel_to sh("2026-09-14 01:00") do
      ModelCall.create!(status: "ok", created_at: sh("2026-09-14 00:10"))
      ModelCall.create!(status: "ok", created_at: sh("2026-09-13 23:50"))
      assert_equal 1, Reasons::Budget.today_calls
    end
  end
end
