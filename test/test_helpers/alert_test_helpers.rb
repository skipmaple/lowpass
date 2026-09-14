# 告警测试的两个助手：临时换一份渠道配置（进程级，用完还原）；造一条事件
module AlertTestHelpers
  WEBHOOK = "https://hooks.example/lowpass".freeze

  def with_alert_channels(**env)
    Alerts::Config.load!(env.transform_keys(&:to_s))
    yield
  ensure
    Alerts::Config.load!({})
  end

  def alert_event(**overrides)
    AlertEvent.create!({ kind: "source_failed", level: "warning", source: sources(:hn), issue: issues(:daily_0908), summary: "连接超时",
                         url_path: "/admin/sources/#{sources(:hn).id}/runs", dedup_key: "source_failed:#{sources(:hn).id}:2026-09-08" }.merge(overrides))
  end
end
