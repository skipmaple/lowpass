# 理由与独立翻译共用预算门；网络不在行事务内，账本在业务保存之前。
module ModelRequests
  Busy = Class.new(StandardError)
  LOCK_NAMESPACE = 1280332627
  LOCK_KEY = 1
  OPERATION_LIFETIME = 7.days

  class << self
    def operation(key: SecureRandom.uuid, issued_at: Time.current)
      { "key" => key, "issued_at" => issued_at.iso8601(6) }
    end

    def valid_operation?(operation)
      return false unless operation.is_a?(Hash) && operation["key"].is_a?(String) && operation["key"].present? && operation["key"].length <= 36

      issued = Time.iso8601(operation.fetch("issued_at"))
      issued <= Time.current && issued > OPERATION_LIFETIME.ago
    rescue KeyError, ArgumentError, TypeError
      false
    end

    def synchronize
      ApplicationRecord.connection_pool.with_connection do |connection|
        acquired = connection.uncached { connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_NAMESPACE}, #{LOCK_KEY})") }
        raise Busy, "已有模型请求正在处理" unless acquired

        begin
          connection.uncached { yield }
        ensure
          connection.uncached { connection.select_value("SELECT pg_advisory_unlock(#{LOCK_NAMESPACE}, #{LOCK_KEY})") }
        end
      end
    end

    def calls(item, purpose:, operation:, field: nil)
      ModelCall.where(item_id: item.id, purpose: purpose, operation_key: operation.fetch("key"), input_field: field)
    end

    def stop_reason(operation)
      ModelOperationStop.find_by(operation_key: operation.fetch("key"))&.reason
    end

    # 调用方已持有共享门；无真实请求时也能持久记录预算终止，不增加账本调用数。
    def halt(operation, reason)
      stop = ModelOperationStop.find_or_create_by!(operation_key: operation.fetch("key")) do |stop|
        stop.reason = reason
        stop.expires_at = Time.iso8601(operation.fetch("issued_at")) + OPERATION_LIFETIME
      end
      stop.reason
    end

    def record(item, status, response, started, error = nil, purpose:, operation:, configuration:, field: nil, input_digest: nil)
      prompt = response&.prompt_tokens.to_i
      completion = response&.completion_tokens.to_i
      ModelCall.create!(issue_id: item.issue_id, item_id: item.id, status: status, purpose: purpose,
        operation_key: operation.fetch("key"), input_field: field, input_digest: input_digest,
        prompt_tokens: prompt, completion_tokens: completion,
        cost: Reasons::Budget.cost_for(prompt, completion, input_price: configuration.input_price, output_price: configuration.output_price),
        duration_ms: now_ms - started, error_summary: error&.slice(0, 200))
    end

    def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end
end
