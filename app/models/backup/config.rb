# 备份配置只从环境读（设计 §2.5），进程内读一次；测试用 load! 换一份。空串等于没配：Kamal 对没值的变量注入空串。
# 配不全或值不合法都算没配，problems 逐条说清楚——启动日志、设置页与失败摘要都用它。密钥只在这里，不进页面、不进日志
module Backup::Config
  NAMES = %w[ BACKUP_BUCKET_URL BACKUP_REGION BACKUP_ACCESS_KEY_ID BACKUP_SECRET_ACCESS_KEY BACKUP_ENCRYPTION_KEY ].freeze
  # 本机的 http 给演练用（同模型端点的规则，Reasons::Provider::LOCAL_HOSTS）
  LOCAL_HOSTS = %w[ localhost 127.0.0.1 ].freeze
  REGION = /\A[a-z0-9-]{1,64}\z/

  class << self
    def load!(env = ENV)
      @values = NAMES.index_with { |name| env[name].to_s.strip.presence }
      @problems = check(@values)
      @loaded = true
      self
    end

    def bucket_url = loaded && @values["BACKUP_BUCKET_URL"]&.sub(%r{/+\z}, "")
    def region = loaded && @values["BACKUP_REGION"]
    def access_key_id = loaded && @values["BACKUP_ACCESS_KEY_ID"]
    def secret_access_key = loaded && @values["BACKUP_SECRET_ACCESS_KEY"]
    def encryption_key = Lowpass::BackupCipher.key(loaded && @values["BACKUP_ENCRYPTION_KEY"])
    def problems = loaded && @problems

    def any_given? = loaded && @values.values.any?
    def configured? = problems.empty?

    # 设置页的「存储」一行：主机与路径，不含任何密钥。地址不合法就不画
    def storage_label
      uri = URI(bucket_url.to_s)
      "#{uri.host}#{uri.path}" if valid_url?(bucket_url)
    end

    # 设置页的「加密密钥」一行：指纹与备份文件头里的、解密报错里的是同一串，换过密钥一眼能对上
    def key_fingerprint
      Lowpass::BackupCipher.fingerprint(encryption_key) if loaded && @values["BACKUP_ENCRYPTION_KEY"].to_s.match?(Lowpass::BackupCipher::KEY)
    end

    private
      def loaded
        load! unless @loaded
        true
      end

      def check(values)
        problems = NAMES.select { |name| values[name].nil? }.map { |name| "缺 #{name}" }
        problems << "BACKUP_BUCKET_URL 必须是 https 地址" if values["BACKUP_BUCKET_URL"] && !valid_url?(values["BACKUP_BUCKET_URL"])
        problems << "BACKUP_REGION 只能有小写字母、数字与连字符" if values["BACKUP_REGION"] && !values["BACKUP_REGION"].match?(REGION)
        if values["BACKUP_ENCRYPTION_KEY"] && !values["BACKUP_ENCRYPTION_KEY"].match?(Lowpass::BackupCipher::KEY)
          problems << "BACKUP_ENCRYPTION_KEY 必须是 64 位十六进制（openssl rand -hex 32）"
        end
        problems
      end

      # https；本机的 http 也行。带查询、片段或账号口令的都不算：对象地址是它后面直接接 /<对象名>
      def valid_url?(url)
        uri = URI(url.to_s)
        uri.host.present? && uri.query.nil? && uri.fragment.nil? && uri.userinfo.nil? &&
          (uri.is_a?(URI::HTTPS) || (uri.is_a?(URI::HTTP) && LOCAL_HOSTS.include?(uri.host)))
      rescue URI::Error
        false
      end
  end
end
