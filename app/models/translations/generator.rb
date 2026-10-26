# 独立翻译只消费冻结目标；理由与画像不决定资格，失败回复不进入业务存储。
module Translations::Generator
  ATTEMPTS = 3
  Outcome = Data.define(:translated, :reused, :preserved, :failed, :skipped, :stop_reason)

  class << self
    def generate!(issue, targets:, operation:, reassess: false)
      counts = Hash.new(0)
      stopped = if !ModelRequests.valid_operation?(operation)
        "expired"
      elsif !Reasons::Provider.configured?
        "unconfigured"
      end

      targets.uniq.each do |target|
        break if stopped

        counts[generate_target(issue, target, operation, reassess: reassess)] += 1
        stopped = ModelRequests.valid_operation?(operation) ? ModelRequests.stop_reason(operation) : "expired"
      end
      if stopped.nil? && Reasons::Budget.exhausted?
        ModelRequests.synchronize { stopped = ModelRequests.halt(operation, "budget") if Reasons::Budget.exhausted? }
      end
      Outcome.new(**%i[ translated reused preserved failed skipped ].index_with { |key| counts[key] }, stop_reason: stopped)
    end

    private
      def generate_target(issue, target, operation, reassess:)
        ATTEMPTS.times do
          outcome = ModelRequests.synchronize do
            return :skipped unless ModelRequests.valid_operation?(operation)
            return :skipped if ModelRequests.stop_reason(operation)

            item = issue.items.includes(:source, :issue, :translation_preservations).find_by(id: target["item_id"])
            return :skipped unless item && item.translation_target == target && item.needs_translation?(reassess: reassess)

            calls = ModelRequests.calls(item, purpose: "translation", operation: operation, field: target.fetch("field"))
            return :skipped if calls.where(status: "ok").exists?
            return :failed if calls.count >= ATTEMPTS

            if previous = previous_translation(item, target.fetch("field"), reassess: reassess)
              return item.store_translation(previous, target: target, assessed_at: Time.current) ? :reused : :skipped
            end
            if Reasons::Budget.exhausted?
              ModelRequests.halt(operation, "budget")
              return :skipped
            end
            return :skipped unless Reasons::Provider.configured?

            request(item, target, operation)
          end
          return outcome if outcome
        end
        :failed
      end

      def previous_translation(item, field, reassess:)
        previous = Item.visible.daily.includes(:source, :issue, :translation_preservations)
          .where(source_id: item.source_id, url_hash: item.url_hash, field => item.public_send(field))
          .where(issues: { state: "published" }).where("issues.period_key < ?", item.issue.period_key)
          .order("issues.period_key DESC")
        previous.each do |candidate|
          next unless candidate.translation_field == field

          if candidate.public_send("#{field}_zh").present?
            begin
              return Translations::Parser.parse({ decision: "translated", text: candidate.public_send("#{field}_zh") }.to_json, field: field)
            rescue Translations::Parser::Invalid
              next
            end
          elsif !reassess && !candidate.needs_translation?
            return Translations::Parser::Result.new(decision: "unchanged", text: nil)
          end
        end
        nil
      end

      def request(item, target, operation)
        field = target.fetch("field")
        configuration = Reasons::Provider.configuration
        started = ModelRequests.now_ms
        response = result = nil
        begin
          response = Reasons::Provider.chat(Translations::Prompt.messages(item, field: field),
            max_tokens: Translations::Prompt.max_tokens(field), configuration: configuration)
          result = Translations::Parser.parse(response.text, field: field)
        rescue Translations::Parser::Invalid => e
          record(item, target, operation, configuration, started, "invalid", response, e.message)
        rescue Reasons::Provider::Rejected, Reasons::Provider::Limited => e
          record(item, target, operation, configuration, started, "failed", nil, e.message)
          ModelRequests.halt(operation, e.is_a?(Reasons::Provider::Limited) ? "limited" : "rejected")
          return :failed
        rescue Reasons::Provider::TimedOut => e
          record(item, target, operation, configuration, started, "timed_out", nil, e.message)
        rescue Reasons::Provider::Error => e
          record(item, target, operation, configuration, started, "failed", nil, e.message)
        end
        if result
          record(item, target, operation, configuration, started, "ok", response)
          if item.store_translation(result, target: target, assessed_at: Time.current)
            result.decision == "translated" ? :translated : :preserved
          else
            :skipped
          end
        end
      end

      def record(item, target, operation, configuration, started, status, response, error = nil)
        ModelRequests.record(item, status, response, started, error, purpose: "translation", operation: operation,
          configuration: configuration, field: target.fetch("field"), input_digest: target.fetch("input_digest"))
      end
  end
end
