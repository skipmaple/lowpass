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

  test "没有调用记录时，月费用仍是 BigDecimal（sum 在空表上回落到 Integer 0）" do
    assert_instance_of BigDecimal, Reasons::Budget.month_cost
  end

  test "合法拒写在上海日月边界计入次数费用与状态页" do
    travel_to sh("2026-10-01 00:10") do
      ModelCall.create!(status: "abstained", cost: "0.2", created_at: sh("2026-10-01 00:00"))
      ModelCall.create!(status: "abstained", cost: "0.3", created_at: sh("2026-09-30 23:59"))
      assert_equal BigDecimal("0.2"), Reasons::Budget.month_cost
      assert_equal 1, Reasons::Budget.today_calls
      assert_equal 1, Reasons::Budget.month_calls
      assert_equal [ 1, 1, "0.2" ], Reasons::Status.props.values_at(:month_calls, :today_calls, :month_cost)
    end
  end
  test "mixed currency costs are not added and fallback has no primary cap" do
    Setting.set("model_currency", "USD")
    Setting.set("model_monthly_cap", "5")
    ModelCall.create!(status: "ok", cost: 2, currency: "USD", provider_host: "api.openai.com", provider_model: "gpt-6-luna")
    ModelCall.create!(status: "ok", cost: 8, currency: "CNY", provider_host: "api.siliconflow.cn", provider_model: "deepseek-ai/DeepSeek-V4-Flash")
    ModelCall.create!(status: "ok", cost: 7) # 币种未知，不可混入 USD。
    assert_equal BigDecimal("2"), Reasons::Budget.month_cost
    assert_not Reasons::Budget.exhausted?
    groups = Reasons::Budget.month_usage
    assert_equal [ "CNY", "USD" ], groups.filter_map { |group| group[:currency] }.sort
    assert_equal [ "2.0", "7.0", "8.0" ], groups.map { |group| group[:cost] }.sort
  end
end
