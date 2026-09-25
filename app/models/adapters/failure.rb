module Adapters
  # 抓取失败对管理员说的那一句原因（附录 B「重抓失败：{reason}」「抓取失败：{reason}」）：抓取记录、重抓结束的提示、
  # 信息源列表的「上次抓取」都读它。只说发生了什么，不带异常类名、源站地址这些内部细节——原始报错照旧进告警
  # （Alerts.source_failed! 收的是 error.message）与日志，排查从那里看。
  module Failure
    REASONS = {
      Rss::ParseError => "不是有效的 RSS/Atom",
      GithubTrending::ParseError => "页面结构变了，解析不到条目",
      RuanyfWeekly::Degraded => "解析出的条目太少，原文结构可能变了",
      Timeout::Error => "连接超时",
      Http::Blocked => "源站拒绝了请求（429 / 403）",
      Http::Unresolvable => "地址解析不到公网 IP",
      Http::TooLarge => "响应超过 2 MB",
      NoBackfill => "该来源无法回填"
    }.freeze

    def self.reason(error)
      REASONS.each { |klass, reason| return reason if error.is_a?(klass) }

      if error.is_a?(Http::Error)
        # Http 把非 2xx 写成「500 for https://…」，把连不上、证书、读超时这类底层异常原样包进来
        (code = error.message[/\A(\d{3})\b/, 1]) ? "源站返回 HTTP #{code}" : "连接源站失败"
      else
        # 没料到的异常（解析器的毛病之类）：留第一行给管理员一个线索
        "抓取出错：#{error.message.to_s.lines.first.to_s.strip[0, 120]}"
      end
    end
  end
end
