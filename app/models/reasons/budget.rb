# 费用与上限（R-9.8、N-10）：费用 = token 数 × 后台填的每百万 token 单价；月与日都按上海时区；上限 0 = 不限（设计 C8）
module Reasons::Budget
  class << self
    def cap = decimal(Setting.get("model_monthly_cap"))
    def month_cost = ModelCall.where(request_made: true, created_at: month_range, currency: Setting.get("model_currency").presence).sum(:cost).to_d
    def month_calls = ModelCall.where(request_made: true, created_at: month_range).count
    def month_calls_by_purpose = ModelCall.where(request_made: true, created_at: month_range).group(:purpose).count
    def today_calls = ModelCall.where(request_made: true, created_at: day_range).count
    def exhausted? = cap.positive? && month_cost >= cap

    def month_usage
      ModelCall.where(request_made: true, created_at: month_range).group(:provider_host, :provider_model, :currency)
        .pluck(:provider_host, :provider_model, :currency, Arel.sql("COUNT(*)"), Arel.sql("SUM(cost)"), Arel.sql("SUM(prompt_tokens)"), Arel.sql("SUM(completion_tokens)"))
        .map do |host, model, currency, count, cost, prompt, completion|
          { provider: host, model: model, currency: currency, calls: count, cost: cost.to_d.to_s("F"), prompt_tokens: prompt, completion_tokens: completion }
        end
    end

    def cost_for(prompt_tokens, completion_tokens, input_price: nil, output_price: nil, cached_tokens: 0, cache_write_tokens: 0, cached_input_price: nil, cache_write_price: nil)
      per_million = BigDecimal("1000000")
      input = decimal(input_price || Setting.get("model_input_price"))
      cached = cached_tokens.to_i.clamp(0, prompt_tokens.to_i)
      writes = cache_write_tokens.to_i.clamp(0, prompt_tokens.to_i - cached)
      ordinary = prompt_tokens.to_i - cached - writes
      ((ordinary * input + cached * decimal(cached_input_price || input) + writes * decimal(cache_write_price || input) +
        completion_tokens.to_i * decimal(output_price || Setting.get("model_output_price"))) / per_million).round(8)
    end

    private
      def decimal(value) = BigDecimal(value.to_s.presence || "0")
      def now = Time.current.in_time_zone(PeriodKey::ZONE)
      def month_range = now.beginning_of_month.utc..now.end_of_month.utc
      def day_range = now.beginning_of_day.utc..now.end_of_day.utc
  end
end
