class FetchSourceJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(source, issue, _trigger) { [ source.id, issue&.id ] }, duration: 20.minutes
  WAITS = [ 30.seconds, 120.seconds ].freeze

  retry_on Adapters::Http::Error, Timeout::Error, wait: ->(executions) { WAITS[executions - 1] || WAITS.last }, attempts: 3
  discard_on Adapters::Http::Blocked   # 429 / 403 不追加请求
  discard_on Adapters::Http::Unresolvable

  def perform(source, issue, trigger)
    source.fetch_now(issue, trigger: trigger, attempt: executions)
  end
end
