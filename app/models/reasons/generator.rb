# 给一期日刊生成理由（5.9、设计 §4.3）：一期顺序做，单条重试 2 次；上限到了就停并告警；跨天重复沿用前一期（R-1.11）；
# 每次调用记一条账本；跑完没有缺理由的条目就收掉「推荐理由缺失」事件
module Reasons::Generator
  RETRIES = 2
  Outcome = Data.define(:generated, :reused, :failed, :skipped)

  class << self
    def generate!(issue, only_missing: true)
      return Outcome.new(generated: 0, reused: 0, failed: 0, skipped: true) unless Reasons.ready?

      items = issue.items.visible.ranked.includes(:source, :issue).to_a
      items = items.select { |item| item.reason.nil? } if only_missing
      names = InterestArea.enabled_names
      profile = InterestArea.profile_text
      counts = Hash.new(0)

      items.each do |item|
        if Reasons::Budget.exhausted?
          missing = issue.items.visible.where(reason: nil).count
          Alerts.reasons_missing!(issue, missing, summary: "本月费用已达上限，缺理由 #{missing} 条")
          break
        end
        # 沿用只在补缺时算数：整期重生成（only_missing: false）就是要覆盖旧理由，
        # 跨天重复的那几条也得真的重新生成，不然这个按钮对它们没有效果（R-9.7）
        if only_missing && (previous = previous_reason(item))
          item.update!(reason: previous.reason, interest_tag: previous.interest_tag, reason_generated_at: Time.current)
          counts[:reused] += 1
          next
        end
        begin
          counts[generate_item!(item, names: names, profile: profile) ? :generated : :failed] += 1
        rescue Reasons::Provider::Rejected, Reasons::Provider::Limited => e
          # 密钥被拒绝 / 被限流：后面每一条都会一样，本期到此为止（记账在 generate_item! 里已经写过）。
          # 429 不在条内重试，也不在期内接着打——仓库不变量「429 / 403 不追加重试」（设计 C11）
          counts[:failed] += 1
          Rails.error.report(e, handled: true, context: { issue: issue.period_key })
          break
        end
      end

      Alerts.recover!(kind: "reasons_missing") if issue.items.visible.where(reason: nil).none?
      Outcome.new(generated: counts[:generated], reused: counts[:reused], failed: counts[:failed], skipped: false)
    end

    # 单条：最多 1 + RETRIES 次调用，每次都记账；成功写回 items（update!：R-9.7 唯一可补写的字段，走 Searchable 回调无害）
    def generate_item!(item, names: InterestArea.enabled_names, profile: InterestArea.profile_text)
      # 两道前提各自成立：读者页的单条重生成不经过 generate! 的循环，同样不能在画像为空
      # 或月上限到了的时候调模型（终审 F1、F2）
      return false unless Reasons.ready?
      return false if Reasons::Budget.exhausted?

      messages = Reasons::Prompt.messages(item, profile)
      (RETRIES + 1).times do
        started = now_ms
        response = nil
        begin
          response = Reasons::Provider.chat(messages)
          result = Reasons::Parser.parse(response.text, names)
          record(item, "ok", response, started)
          item.update!(reason: result.reason, interest_tag: result.interest_tag, reason_generated_at: Time.current)
          return true
        rescue Reasons::Parser::Invalid => e
          record(item, "invalid", response, started, e.message)
        rescue Reasons::Provider::Rejected => e
          record(item, "failed", nil, started, "密钥被拒绝")
          raise
        rescue Reasons::Provider::Limited => e
          # 429 不追加重试（仓库不变量）：记一条就往上抛，由 generate! 停掉本期
          record(item, "failed", nil, started, e.message)
          raise
        rescue Reasons::Provider::TimedOut => e
          record(item, "timed_out", nil, started, e.message)
        rescue Reasons::Provider::Error => e
          record(item, "failed", nil, started, e.message)
        end
      end
      false
    end

    private
      # R-1.11 同一条目跨天重复：更早的日刊里同 url_hash 且已有理由的那条
      def previous_reason(item)
        Item.joins(:issue).where(url_hash: item.url_hash, issues: { kind: "daily" }).where("issues.period_key < ?", item.issue.period_key)
            .where.not(reason: nil).order("issues.period_key DESC").first
      end

      def record(item, status, response, started, error = nil)
        prompt = response&.prompt_tokens.to_i
        completion = response&.completion_tokens.to_i
        ModelCall.create!(issue: item.issue, item: item, status: status, prompt_tokens: prompt, completion_tokens: completion,
                          cost: Reasons::Budget.cost_for(prompt, completion), duration_ms: now_ms - started, error_summary: error&.slice(0, 200))
      end

      def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end
end
