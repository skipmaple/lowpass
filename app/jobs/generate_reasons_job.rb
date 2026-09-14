# 一期一个（设计 C3）：发布后入队（Issue::Finalization）、重抓后补缺（Issue::Daily#revise!）、后台整期重生成（only_missing = false）。
# 单条重试在 Generator 里；job 本身不 retry_on，异常记进错误报告再抛出，队列面板可见
class GenerateReasonsJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(issue, *) { issue.id }, duration: 10.minutes

  def perform(issue, only_missing = true)
    Reasons::Generator.generate!(issue, only_missing: only_missing)
  rescue StandardError => e
    Rails.error.report(e, handled: false, context: { issue: issue.period_key })
    raise
  end
end
