# 一期一个（设计 C3）：发布后入队（Issue::Finalization）、重抓后补缺（Issue::Daily#revise!）、后台整期重生成（only_missing = false）。
# 单条重试在 Generator 里；job 本身不 retry_on，异常记进错误报告再抛出，队列面板可见
class GenerateReasonsJob < ApplicationJob
  queue_as :default
  # 本地推理单条可能接近两分钟；整期的有限重试期间也必须锁住，避免后台重复点击后并发覆盖。
  limits_concurrency to: 1, key: ->(issue, *) { issue.id },
                     duration: Rails.env.development? && ENV["MODEL_LOCAL_COMPAT"] == "1" ? 4.hours : 10.minutes

  def perform(issue, only_missing = true)
    Reasons::Generator.generate!(issue, only_missing: only_missing)
  rescue StandardError => e
    Rails.error.report(e, handled: false, context: { issue: issue.period_key })
    raise
  end
end
