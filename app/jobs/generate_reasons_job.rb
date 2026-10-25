# 一期一个（设计 C3）：发布后入队（Issue::Finalization）、重抓后补缺（Issue::Daily#revise!）、后台整期重生成（only_missing = false）。
# 单条重试在 Generator 里；job 本身不 retry_on，异常记进错误报告再抛出，队列面板可见
class GenerateReasonsJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(issue, *) { issue.id }, duration: 10.minutes
  retry_on ModelRequests::Busy, wait: 5.seconds, attempts: :unlimited
  before_enqueue :freeze_context

  def perform(issue, only_missing = true, context = nil)
    # 旧队列参数没有翻译授权；原入队时刻决定其剩余有效期，不以重排刷新。
    context ||= legacy_context
    self.arguments = [ issue, only_missing, context ]
    return unless ModelRequests.valid_operation?(context.fetch("operation"))

    result = Reasons::Generator.generate!(issue, only_missing: only_missing, operation: context.fetch("operation"))
    if context.fetch("translation_targets").any? && result.stop_reason.in?([ nil, "profile_empty" ])
      payload = { "operation" => context.fetch("operation"), "targets" => context.fetch("translation_targets"), "reassess" => false }
      GenerateTranslationsJob.perform_now(issue, payload)
    end
  rescue ModelRequests::Busy
    raise
  rescue StandardError => e
    Rails.error.report(e, handled: false, context: { issue: issue.period_key })
    raise
  end

  private
    def freeze_context
      issue, only_missing = arguments
      self.arguments = [ issue, only_missing.nil? ? true : only_missing, arguments[2] || legacy_context ]
    end

    def legacy_context
      issued = enqueued_at || Time.current
      issued = Time.iso8601(issued) if issued.is_a?(String)
      { "operation" => ModelRequests.operation(key: job_id, issued_at: issued), "translation_targets" => [] }
    end
end
