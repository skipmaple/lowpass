# R-3.3 测试抓取：拿表单当前的配置建一个不保存的源，30 秒内抓一次，回前 5 条预览与解析警告；
# 失败给一句读得懂的原因（P2 退出条件「测试抓取的错误信息可读」）。源已保存时记一条 trigger=test 的抓取记录（R-3.9）。
class Source::TestFetch
  Result = Data.define(:ok, :entries, :warnings, :parsed, :dropped, :duration_ms, :feed_title, :error)
  PREVIEW = 5

  MESSAGES = {
    Adapters::Rss::ParseError => "不是有效的 RSS/Atom，请检查地址。",
    Timeout::Error => "连接超时（30 秒），请检查地址或稍后重试。",
    Adapters::Http::Blocked => "源站拒绝了请求（429 / 403）。",
    Adapters::Http::Unresolvable => "地址解析不到公网 IP。",
    Adapters::Http::TooLarge => "响应超过 2 MB。"
  }.freeze
  FAILURES = [ *MESSAGES.keys, Adapters::Http::Error, Adapters::GithubTrending::ParseError, Adapters::RuanyfWeekly::Degraded ].freeze

  def self.call(attrs)
    new(attrs).call
  end

  def initialize(attrs)
    attrs = attrs.to_h.symbolize_keys
    @id = attrs[:id].presence
    @source = Source.new(attrs.slice(:name, :adapter, :publication, :config))
    @source.id = @id if @id
  end

  def call
    if (problems = config_problems).any?
      failure("配置不完整：#{problems.join("；")}", record: false)
    else
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      entries = adapter.test_fetch
      success(entries, elapsed(@started))
    end
  rescue *FAILURES => e
    failure(message_for(e), status: e.is_a?(Timeout::Error) ? "timed_out" : "failed", duration_ms: elapsed(@started))
  end

  private
    attr_reader :source

    def adapter
      @adapter ||= source.adapter_class.new(source)
    end

    # 只看配置与刊物的错误：名称重复不妨碍试抓；feed 地址跟别的源重复（:duplicate）是保存时的事，表单在保存时报，试抓只答「能不能抓」
    def config_problems
      source.valid?
      source.errors.filter_map do |error|
        name = error.attribute.to_s.delete_prefix("config.")
        if error.attribute == :publication
          error.message
        elsif error.attribute.to_s.start_with?("config.") && error.type != :duplicate
          "#{Source::Config::LABELS.fetch(name, name)}#{error.message}"
        end
      end
    end

    def success(entries, duration_ms)
      kept, dropped = entries.partition(&:valid?)
      warnings = []
      warnings << "#{dropped.size} 条缺标题或链接，已丢弃" if dropped.any?
      untimed = kept.count { |entry| entry.meta.to_h[:time_from_fetch] || entry.meta.to_h["time_from_fetch"] }
      warnings << "#{untimed} 条无发布时间，已用抓取时间代替" if untimed.positive?
      record("succeeded", parsed: entries.size, dropped: dropped.size, duration_ms: duration_ms)
      Result.new(ok: true, entries: kept.first(PREVIEW).map { |entry| preview(entry) }, warnings: warnings, parsed: entries.size,
                 dropped: dropped.size, duration_ms: duration_ms, feed_title: adapter.try(:feed_title), error: nil)
    end

    def failure(message, status: "failed", record: true, duration_ms: 0)
      record(status, error_summary: message, duration_ms: duration_ms) if record
      Result.new(ok: false, entries: [], warnings: [], parsed: 0, dropped: 0, duration_ms: duration_ms, feed_title: nil, error: message)
    end

    def message_for(error)
      MESSAGES.each { |klass, message| return message if error.is_a?(klass) }
      "抓取失败：#{error.message.to_s.lines.first.to_s.strip[0, 120]}"
    end

    def preview(entry)
      meta = entry.meta.to_h.symbolize_keys
      {
        title: entry.title.to_s.strip[0, 300],
        url: entry.url.to_s.strip,
        summary: SummaryCleaner.clean(entry.summary)&.slice(0, 120),
        author: entry.author&.strip,
        published_label: entry.published_at&.in_time_zone(PeriodKey::ZONE)&.strftime("%m-%d %H:%M"),
        meta: meta.slice(:score, :comments, :language, :stars, :stars_today, :issue_no)
      }
    end

    def record(status, parsed: 0, dropped: 0, duration_ms: 0, error_summary: nil)
      return unless @id

      FetchRun.create!(source_id: @id, issue: nil, trigger: "test", attempt: 1, status: status, started_at: Time.current,
                       item_count: parsed, dropped_count: dropped, duration_ms: duration_ms, error_summary: error_summary&.slice(0, 200))
    end

    def elapsed(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).to_i
    end
end
