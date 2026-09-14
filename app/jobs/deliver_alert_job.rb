# 把一条告警（或它的「已恢复」）发到每个已配置的渠道；按「渠道:阶段」记已送达，重试不重发（设计 B7）。
# R-7.3：发送失败最多重试 3 次，耗尽写一行日志并让 job 失败（队列面板里看得见），事件留着 delivery_error
#
# 没用 retry_on 的 attempts:：它按异常类名累计一个独立的 exception_executions 计数，只在 job 真的
# 走一遍「入队 → 反序列化 → 执行」时才会跟 executions 对齐——deserialize 会把两个计数一起带回来。
# 这里直接按 executions 自己判断是不是最后一次，跟 job 实际执行次数（也是日志里报的次数）严格一致。
class DeliverAlertJob < ApplicationJob
  queue_as :default
  # 恢复阶段的 job 会与告警阶段的重试撞在同一条事件上，两边都读改写 delivered：一条事件只许一个在跑
  limits_concurrency to: 1, key: ->(event, _phase) { event.id }, duration: 10.minutes
  WAITS = [ 30.seconds, 120.seconds ].freeze
  MAX_ATTEMPTS = 3

  rescue_from Alerts::DeliveryError do |error|
    if executions < MAX_ATTEMPTS
      retry_job wait: WAITS[executions - 1] || WAITS.last
    else
      event, phase = arguments
      Rails.logger.error { "告警投递失败（#{phase}，#{executions} 次）：AlertEvent##{event.id} #{error.message}" }
      raise error
    end
  end

  def perform(event, phase)
    errors = []
    Alerts::Channels.configured.each do |channel|
      next if event.delivered?(channel::NAME, phase)
      begin
        channel.deliver(event, phase)
        event.delivered = event.delivered + [ "#{channel::NAME}:#{phase}" ]
        stamp = phase == "recovery" ? :recovery_sent_at : :sent_at
        event[stamp] ||= Time.current
      rescue Alerts::DeliveryError => e
        errors << e.message
      end
    end
    event.attempts += 1
    event.delivery_error = errors.first&.slice(0, 200)
    event.save!
    raise Alerts::DeliveryError, errors.join("; ") if errors.any?
  end
end
