module Source::Fetching
  extend ActiveSupport::Concern

  def fetch_later(issue, trigger: "scheduled")
    FetchSourceJob.perform_later(self, issue, trigger)
  end

  def fetch_now(issue, trigger:, attempt: 1)
    run = fetch_runs.find_by(issue: issue, attempt: attempt, status: "queued") || fetch_runs.new(issue: issue, trigger: trigger, attempt: attempt)
    run.update!(status: "running", started_at: Time.current)
    entries = adapter_class.new(self).fetch(period_key: (issue.period_key if issue&.kind == "weekly"))
    kept, dropped = entries.partition(&:valid?)
    replace_items(issue, kept) if issue
    run.update!(status: "succeeded", item_count: kept.size, dropped_count: dropped.size, duration_ms: elapsed(run))
    run
  rescue Timeout::Error => e
    run.update!(status: "timed_out", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200], duration_ms: elapsed(run))
    raise
  rescue StandardError => e
    run.update!(status: "failed", error_summary: e.message.to_s.lines.first.to_s.strip[0, 200], duration_ms: elapsed(run))
    raise
  end

  def health
    return "disabled" unless enabled?
    recent = fetch_runs.where(trigger: %w[ scheduled manual ]).where.not(status: %w[ running queued ]).ordered.limit(3).pluck(:status)
    return "ok" if recent.empty? || recent.first == "succeeded"
    failures = recent.take_while { |s| s != "succeeded" }.size
    failures >= 3 ? "consecutive_failures" : "recent_failure"
  end

  private
    def replace_items(issue, entries)
      transaction do
        issue.items.where(source: self).delete_all
        rows = entries.map { |e| e.to_item_attributes(source: self, issue: issue) }
        rows.uniq! { |r| r[:url_hash] }   # 同源重复地址保留首次出现
        Item.insert_all!(rows.map { |r| r.merge(id: Lowpass::Uuid.generate, created_at: Time.current, updated_at: Time.current) }) if rows.any?
      end
    end

    def elapsed(run)
      ((Time.current - run.started_at) * 1000).to_i
    end
end
