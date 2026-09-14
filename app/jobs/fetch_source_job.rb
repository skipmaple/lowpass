class FetchSourceJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(source, issue, _trigger, _backfill = false) { [ source.id, issue&.id ] }, duration: 20.minutes
  WAITS = [ 30.seconds, 120.seconds ].freeze
  MAX_ATTEMPTS = 3

  retry_on Adapters::Http::Error, Timeout::Error, wait: ->(executions) { WAITS[executions - 1] || WAITS.last }, attempts: MAX_ATTEMPTS
  discard_on Adapters::Http::Blocked   # 429 / 403 不追加请求
  discard_on Adapters::Http::Unresolvable
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
  ensure
    issue&.finalize_if_done!
  end
end
