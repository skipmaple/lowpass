# 备份测试的助手：临时换一份配置（进程级，用完还原）；造一个假的 pg_dump（不跑真的：CI 的 runner 与 postgres service
# 大版本对不上，真命令会拒绝导出）
module BackupTestHelpers
  BUCKET = "https://lowpass-backup.storage.example/daily".freeze
  BACKUP_ENV = {
    "BACKUP_BUCKET_URL" => BUCKET, "BACKUP_REGION" => "auto", "BACKUP_ACCESS_KEY_ID" => "test-access-key",
    "BACKUP_SECRET_ACCESS_KEY" => "test-secret-key", "BACKUP_ENCRYPTION_KEY" => "ab" * 32
  }.freeze

  def with_backup_config(env = BACKUP_ENV)
    Backup::Config.load!(env.transform_keys(&:to_s))
    yield
  ensure
    Backup::Config.load!({})
  end

  # body 是 shell 脚本的正文；$out 是 --file 指向的输出文件
  def fake_pg_dump(dir, body)
    File.join(dir, "pg_dump").tap do |path|
      File.write(path, <<~SH)
        #!/bin/sh
        for arg in "$@"; do case "$arg" in --file=*) out="${arg#--file=}";; esac; done
        #{body}
      SH
      File.chmod(0o755, path)
    end
  end
end
