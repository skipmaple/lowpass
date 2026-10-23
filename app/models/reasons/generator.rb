# 给一期日刊生成理由（5.9、设计 §4.3）：一期顺序做，单条重试 2 次；上限到了就停并告警；跨天重复沿用前一期（R-1.11）；
# 每次调用记一条账本；跑完没有缺理由且预算未耗尽，才收掉「推荐理由缺失」事件。
# 要译的条目（D25）在同一次调用里拿回译文（HN 与 Hackaday 的标题、GitHub Trending 的简介），跟理由一起写；「缺理由」仍只看理由
module Reasons::Generator
  RETRIES = 2
  Outcome = Data.define(:generated, :reused, :abstained, :failed, :skipped)

  class << self
    def generate!(issue, only_missing: true)
      return Outcome.new(generated: 0, reused: 0, abstained: 0, failed: 0, skipped: true) unless Reasons.ready?

      items = only_missing ? issue.items.pending_reasons : issue.items.visible.daily
      items = items.ranked.includes(:source, :issue).to_a
      names = InterestArea.enabled_names
      profile = InterestArea.profile_text
      counts = Hash.new(0)

      items.each do |item|
        if Reasons::Budget.exhausted?
          alert_budget_exhausted(issue)
          break
        end
        # 沿用只在补缺时算数：整期重生成（only_missing: false）就是要覆盖旧理由，
        # 跨天重复的那几条也得真的重新生成，不然这个按钮对它们没有效果（R-9.7）
        if only_missing && (previous = previous_reason(item))
          store(item, previous)
          Reasons.recover_if_complete(issue)
          counts[:reused] += 1
          next
        end
        begin
          counts[generate_item!(item, names: names, profile: profile)] += 1
        rescue Reasons::Provider::Rejected, Reasons::Provider::Limited => e
          # 密钥被拒绝 / 被限流：后面每一条都会一样，本期到此为止（记账在 generate_item! 里已经写过）。
          # 429 不在条内重试，也不在期内接着打——仓库不变量「429 / 403 不追加重试」（设计 C11）
          counts[:failed] += 1
          Rails.error.report(e, handled: true, context: { issue: issue.period_key })
          break
        end
      end

      Reasons.recover_if_complete(issue)
      Outcome.new(generated: counts[:generated], reused: counts[:reused], abstained: counts[:abstained], failed: counts[:failed], skipped: false)
    end

    # 单条：最多 1 + RETRIES 次调用，每次调用前检查预算、调用后记账；成功写回 items（update!：R-9.7 发布后可补写的字段，走 Searchable 回调无害）
    def generate_item!(item, names: InterestArea.enabled_names, profile: InterestArea.profile_text)
      # 两道前提各自成立：读者页的单条重生成不经过 generate! 的循环，同样不能在画像为空
      # 或月上限到了的时候调模型（终审 F1、F2）
      return :failed unless Reasons.ready?

      messages = Reasons::Prompt.messages(item, profile)
      (RETRIES + 1).times do
        if Reasons::Budget.exhausted?
          alert_budget_exhausted(item.issue)
          return :failed
        end

        started = now_ms
        response = result = nil
        begin
          response = Reasons::Provider.chat(messages, max_tokens: Reasons::Prompt.max_tokens(item))
          result = Reasons::Parser.parse(response.text, names)
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
        # 解析与真实请求账本先完成；业务持久化异常不能触发另一次模型请求。
        if result
          if result.decision == "insufficient_evidence"
            record(item, "abstained", response, started)
            item.record_reason_abstention(assessed_at: Time.current)
            Reasons.recover_if_complete(item.issue)
            return :abstained
          else
            record(item, "ok", response, started)
            store(item, result)
            Reasons.recover_if_complete(item.issue)
            return :generated
          end
        end
      end
      alert_budget_exhausted(item.issue) if Reasons::Budget.exhausted?
      :failed
    end

    private
      def alert_budget_exhausted(issue)
        missing = issue.items.pending_reasons.count
        summary = missing.positive? ? "本月费用已达上限，缺理由 #{missing} 条" : "本月费用已达上限，已停止生成"
        Alerts.reasons_missing!(issue, missing, summary: summary)
      end

      # R-1.11 同一条目跨天重复：更早的日刊里同 url_hash 且已有理由的那条。要译的条目（D25）还得是原文相同、
      # 带着译文的那条——前一条早于译文上线，或源站后来改了标题、仓库改了简介，就不沿用，整条重新生成。
      # GitHub 的仓库常常连着几天上榜，简介不变就一直沿用，不重复花钱
      def previous_reason(item)
        previous = Item.reusable_reasons.where(url_hash: item.url_hash).where("issues.period_key < ?", item.issue.period_key)
        previous = previous.where(title: item.title).where.not(title_zh: nil) if item.translate_title?
        previous = previous.where(summary: item.summary).where.not(summary_zh: nil) if item.translate_summary?
        previous.order("issues.period_key DESC").first
      end

      # generated 是模型的解析结果或跨天沿用的前一条，两者都有 reason / interest_tag / title_zh / summary_zh。
      # 理由与标签每次覆盖（R-9.7）；译文只写这一次真有的：整期重生成时这次没译好，不抹掉上一次的
      # （原文没变，旧译文仍然对得上）；不要这种译文的条目一律不写，哪怕前一条来自要译的源
      def store(item, generated)
        item.store_generated_reason(generated, generated_at: Time.current)
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
