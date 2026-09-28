require "test_helper"

class Backup::DumpTest < ActiveSupport::TestCase
  setup { @dir = Dir.mktmpdir }
  teardown { FileUtils.remove_entry(@dir) }

  test "自定义格式、跳过缓存与 Cable 的数据；连接参数经环境变量，口令不在命令行里" do
    Backup::Dump.stubs(:command).returns(fake_pg_dump(@dir, %(printf '%s\\n' "$*" "$PGDATABASE" "$PGHOST" "$PGPASSWORD" > "$out")))
    Backup::Dump.write(output)

    args, database, host, password = File.read(output).lines.map(&:chomp)
    assert_includes args, "--format=custom"
    assert_includes args, "--no-password"
    assert_includes args, "--exclude-table-data=solid_cache_entries"
    assert_includes args, "--exclude-table-data=solid_cable_messages"
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal config[:database], database
    assert_equal config[:host].to_s, host
    assert_equal config[:password].to_s, password
    assert_not_includes args, config[:password].to_s if config[:password].present?
  end

  test "失败：带上 stderr 的前两行，临时的 stderr 文件不留" do
    Backup::Dump.stubs(:command).returns(fake_pg_dump(@dir, <<~SH))
      echo "pg_dump: error: aborting because of server version mismatch" >&2
      echo "pg_dump: detail: server version: 18.1; pg_dump version: 17.6" >&2
      exit 1
    SH

    error = assert_raises(Backup::Error) { Backup::Dump.write(output) }
    assert_equal "pg_dump 失败：pg_dump: error: aborting because of server version mismatch / pg_dump: detail: server version: 18.1; pg_dump version: 17.6", error.message
    assert_not File.exist?("#{output}.stderr")
  end

  test "没有 stderr 就报退出码" do
    Backup::Dump.stubs(:command).returns(fake_pg_dump(@dir, "exit 3"))
    assert_equal "pg_dump 失败：退出码 3", assert_raises(Backup::Error) { Backup::Dump.write(output) }.message
  end

  test "超时：进程被停掉" do
    Backup::Dump.stubs(:command).returns(fake_pg_dump(@dir, "exec sleep 30"))
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    error = assert_raises(Backup::Error) { Backup::Dump.write(output, timeout: 1.second) }
    assert_equal "pg_dump 超时（1 秒）", error.message
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10
  end

  test "找不到 pg_dump" do
    Backup::Dump.stubs(:command).returns(File.join(@dir, "missing", "pg_dump"))
    assert_match(/\Apg_dump 失败：找不到 /, assert_raises(Backup::Error) { Backup::Dump.write(output) }.message)
  end

  private
    def output = File.join(@dir, "lowpass.dump")
end
