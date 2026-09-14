# 费用与上限（R-9.8、N-10）：费用 = token 数 × 后台填的每百万 token 单价；月与日都按上海时区；上限 0 = 不限（设计 C8）
module Reasons::Budget
  class << self
    def cap = decimal(Setting.get("model_monthly_cap"))
    def month_cost = ModelCall.where(created_at: month_range).sum(:cost)
    def month_calls = ModelCall.where(created_at: month_range).count
    def today_calls = ModelCall.where(created_at: day_range).count
    def exhausted? = cap.positive? && month_cost >= cap

    def cost_for(prompt_tokens, completion_tokens)
      per_million = BigDecimal("1000000")
      (BigDecimal(prompt_tokens.to_i) / per_million * decimal(Setting.get("model_input_price")) +
        BigDecimal(completion_tokens.to_i) / per_million * decimal(Setting.get("model_output_price"))).round(4)
    end

    private
      def decimal(value) = BigDecimal(value.to_s.presence || "0")
      def now = Time.current.in_time_zone(PeriodKey::ZONE)
      def month_range = now.beginning_of_month.utc..now.end_of_month.utc
      def day_range = now.beginning_of_day.utc..now.end_of_day.utc
  end
end
