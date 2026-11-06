# 2026-11-06 硅基流动公开费率；单位 CNY / 百万 tokens。
# https://docs.siliconflow.cn/docs/release-notes/overview#pricing-adjustment-time-based-pricing-for-deepseek-v4-flash
# 显式保留 V4-Flash，不把供应商的新 V4.1 模型或费率套到旧模型上。
module Reasons::Pricing
  def self.siliconflow(model, at: Time.current)
    return unless model == "deepseek-ai/DeepSeek-V4-Flash"

    if (2...8).cover?(at.in_time_zone(PeriodKey::ZONE).hour)
      { input_price: "1.5", output_price: "4.5", cached_input_price: "0.15" }.freeze
    else
      { input_price: "3", output_price: "9", cached_input_price: "0.3" }.freeze
    end
  end
end
