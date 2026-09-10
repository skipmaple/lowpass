class FetchSourceJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(source, issue, _trigger) { [ source.id, issue&.id ] }, duration: 20.minutes
  WAITS = [ 30.seconds, 120.seconds ].freeze
  MAX_ATTEMPTS = 3

  retry_on Adapters::Http::Error, Timeout::Error, wait: ->(executions) { WAITS[executions - 1] || WAITS.last }, attempts: MAX_ATTEMPTS
  discard_on Adapters::Http::Blocked   # 429 / 403 不追加请求
  discard_on Adapters::Http::Unresolvable

  def perform(source, issue, trigger)
    source.fetch_now(issue, trigger: trigger, attempt: executions)
  rescue Adapters::Http::Blocked, Adapters::Http::Unresolvable
    raise                                # discard_on 丢弃，这个源到此为止
  rescue Adapters::Http::Error, Timeout::Error
    # 还要重试的话先占位，让期知道这个源没结束；ensure 早于 retry_on 执行，排队记录这时已经在了
    source.fetch_runs.create!(issue: issue, trigger: trigger, attempt: executions + 1, status: "queued") if executions < MAX_ATTEMPTS
    raise
  ensure
    issue&.finalize_if_done!
  end
end
