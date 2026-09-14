# 设置页「推荐理由」一节的 props（设计 §6.1）：配置、密钥状态、本月 / 今日用量；数字都给字符串或整数，前端直接画
module Reasons::Status
  def self.props
    {
      configured: Reasons::Provider.configured?,
      key_configured: Reasons::Provider.key_configured?,
      base_url: Setting.get("model_base_url"),
      model_name: Setting.get("model_name"),
      input_price: Setting.get("model_input_price"),
      output_price: Setting.get("model_output_price"),
      monthly_cap: Setting.get("model_monthly_cap"),
      month_calls: Reasons::Budget.month_calls,
      month_cost: Reasons::Budget.month_cost.to_s("F"),
      today_calls: Reasons::Budget.today_calls
    }
  end
end
