# 主库导出（设计 §2.1、E6）：pg_dump 自定义格式，自带压缩，pg_restore 能挑表、能调顺序。连接参数取 ActiveRecord 的主库配置，
# 经环境变量交给子进程，口令不出现在命令行里；缓存与 Cable 两张表只留结构、不留数据。10 分钟超时，先 TERM 再 KILL。
# pg_dump 的大版本不能比服务端旧，遇到更新的服务端它会拒绝导出：镜像里的客户端从 PGDG 装，与数据库同为 18（Dockerfile）
module Backup::Dump
  TIMEOUT = 10.minutes
  GRACE = 5.seconds
  EXCLUDED_DATA = %w[ solid_cache_entries solid_cable_messages ].freeze

  class << self
    def write(path, timeout: TIMEOUT)
      errors = "#{path}.stderr"
      pid = Process.spawn(environment, command, "--format=custom", "--no-password", "--file=#{path}",
                          *EXCLUDED_DATA.map { |table| "--exclude-table-data=#{table}" }, in: File::NULL, out: File::NULL, err: errors)
      status = wait(pid, timeout)
      raise Backup::Error, "pg_dump 失败：#{reason(errors, status)}" unless status.success?
    rescue Errno::ENOENT
      raise Backup::Error, "pg_dump 失败：找不到 #{command}"
    ensure
      File.delete(errors) if errors && File.exist?(errors)
    end

    # 测试换成一个假的 pg_dump 脚本
    def command = "pg_dump"

    private
      def environment
        config = ActiveRecord::Base.connection_db_config.configuration_hash
        { "PGHOST" => config[:host], "PGPORT" => config[:port], "PGUSER" => config[:username], "PGPASSWORD" => config[:password],
          "PGDATABASE" => config[:database], "PGGSSENCMODE" => config[:gssencmode] }.transform_values { |value| value&.to_s }
      end

      def wait(pid, timeout)
        waiter = Process.detach(pid)
        return waiter.value if waiter.join(timeout.to_f)

        stop(pid, waiter)
        raise Backup::Error, "pg_dump 超时（#{timeout >= 1.minute ? "#{timeout.in_minutes.to_i} 分钟" : "#{timeout.to_i} 秒"}）"
      end

      def stop(pid, waiter)
        Process.kill("TERM", pid)
        return if waiter.join(GRACE.to_i)

        Process.kill("KILL", pid)
        waiter.join
      rescue Errno::ESRCH
        nil
      end

      # pg_dump 的报错常是两行：「error: …」加「detail: …」（比如版本不匹配时的两边版本号），两行都留
      def reason(errors, status)
        lines = File.exist?(errors) ? File.read(errors, 2048).to_s.scrub.lines.map(&:strip).reject(&:empty?) : []
        lines.first(2).join(" / ").presence || "退出码 #{status.exitstatus}"
      end
  end
end
