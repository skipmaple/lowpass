# Rails.error.report 自己一个字都不写，只转给订阅者；lowpass 不接外部错误追踪服务，由这个订阅者把每次报告写成一行日志
# （config/initializers/error_reporting.rb 挂上）。上下文只挑白名单里的键：Authentication 放进去的 user_id、
# Search::Runner 带上的原始搜索词都不写，两样落在同一行就把搜索和人连起来了（D12）；控制器、job 对象也不整个倒出来
module Lowpass
  class ErrorLog
    # 值都是自己生成的（步骤名、true、周期键、健康检查的项名、备份记录的 id），原样写
    CONTEXT_KEYS = %i[ step alerts issue health backup_run ].freeze

    # 订阅者不能抛异常：development 与 test 没给 Rails.error 配 logger，这里一抛就穿过调用方的 rescue 冒出去
    # （production 只记一行 fatal）
    def report(error, handled:, severity:, context:, source:)
      Rails.logger.public_send(severity == :warning ? :warn : severity) { line(error, handled, severity, context, source) }
    end

    private
      def line(error, handled, severity, context, source)
        fields = { severity: severity, handled: handled, source: source, **context.slice(*CONTEXT_KEYS) }
        "错误上报：#{error.class} #{first_line(error.message).inspect} #{fields.map { |key, value| "#{key}=#{value}" }.join(" ")}"
      end

      # 只取第一行：数据库错误从第二行起是 DETAIL 与 SQL，可能带着邮箱之类的值。再 inspect 一下，
      # 源站或模型响应里的控制字符伪造不出另一行日志
      def first_line(message) = message.to_s.lines.first.to_s.chomp
  end
end
