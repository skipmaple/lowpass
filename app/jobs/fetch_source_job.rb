class FetchSourceJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(source, issue, _trigger, _backfill = false) { [ source.id, issue&.id ] }, duration: 20.minutes
  WAITS = [ 30.seconds, 120.seconds ].freeze
  MAX_ATTEMPTS = 3

  # 5.7「一次调度内 3 次尝试均失败」：耗尽时告警一次再照常抛出（队列面板里仍能看到失败）
  retry_on Adapters::Http::Error, Timeout::Error, wait: ->(executions) { WAITS[executions - 1] || WAITS.last }, attempts: MAX_ATTEMPTS do |job, error|
    source, issue = job.arguments
    Alerts.source_failed!(source, issue, error.message)
    raise error
  end
  # 429 / 403 与解析不到公网 IP 不追加请求：丢弃，但这也是一次终态失败，要告警
  discard_on Adapters::Http::Blocked, Adapters::Http::Unresolvable do |job, error|
    source, issue = job.arguments
    Alerts.source_failed!(source, issue, error.message)
  end
  discard_on Adapters::NoBackfill      # 设计上的「不能」，重试与告警都没有意义

  def perform(source, issue, trigger, backfill = false)
    if issue&.kind == "weekly" && trigger == "manual"
      Issue.refetch_weekly!(issue, source, attempt: executions)
    else
      source.fetch_now(issue, trigger: trigger, attempt: executions, backfill: backfill)
    end
  rescue Adapters::Http::Blocked, Adapters::Http::Unresolvable, Adapters::NoBackfill
    raise                                # discard_on 丢弃，这个源到此为止
  rescue Adapters::Http::Error, Timeout::Error
    # 还要重试的话先占位，让期知道这个源没结束；ensure 早于 retry_on 执行，排队记录这时已经在了
    source.queue_retry(issue, trigger: trigger, attempt: executions + 1) if executions < MAX_ATTEMPTS
    raise
  rescue StandardError => e
    # 解析异常之类不重试：这一次就是终态
    Alerts.source_failed!(source, issue, e.message)
    raise
  ensure
    issue&.finalize_if_done!
  end
end
