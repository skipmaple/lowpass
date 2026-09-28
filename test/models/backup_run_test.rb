require "test_helper"

class BackupRunTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    Backup::Dump.stubs(:command).returns(fake_pg_dump(@dir, %(printf 'PGDMP pretend dump' > "$out")))
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "成功：导出、加密、上传；存储里的就是加密后的导出" do
    travel_to Time.utc(2026, 9, 28, 19, 0, 5)
    uploaded = nil
    stub_request(:put, %r{\A#{BUCKET}/}).to_return do |request|
      uploaded = request.body
      { status: 200 }
    end

    with_backup_config do
      run = BackupRun.create!(trigger: "scheduled", status: "queued")
      run.perform_now

      assert_equal "succeeded", run.status
      assert_equal 1, run.attempts
      # 并行测试的 worker 各有各的库（lowpass_test、lowpass_test_2 …）：对象名跟着真实的库名走
      name = "#{ActiveRecord::Base.connection_db_config.database}-20260928T190005Z.dump.enc"
      assert_equal name, run.object_key
      assert_equal uploaded.bytesize, run.size_bytes
      assert_not_nil run.duration_ms
      assert_not_nil run.finished_at
      assert_requested :put, "#{BUCKET}/#{name}"

      File.binwrite(File.join(@dir, "uploaded.enc"), uploaded)
      Lowpass::BackupCipher.decrypt(File.join(@dir, "uploaded.enc"), File.join(@dir, "restored.dump"), key: Backup::Config.encryption_key)
      assert_equal "PGDMP pretend dump", File.read(File.join(@dir, "restored.dump"))
    end
  end

  test "失败：记下原因并抛出" do
    stub_request(:put, %r{\A#{BUCKET}/}).to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")

    with_backup_config do
      run = BackupRun.create!(trigger: "manual", status: "queued")
      assert_raises(Backup::Error) { run.perform_now(attempt: 2) }

      assert_equal "failed", run.reload.status
      assert_equal 2, run.attempts
      assert_equal "上传失败（403）：AccessDenied", run.error_summary
      assert_nil run.object_key
      assert_not_nil run.finished_at
    end
  end

  test "没配好：不导出，直接记失败" do
    Backup::Dump.expects(:write).never
    run = BackupRun.create!(trigger: "scheduled", status: "queued")

    assert_raises(Backup::Error) { run.perform_now }
    assert_equal "failed", run.status
    assert_equal "未配置备份：缺 BACKUP_BUCKET_URL、缺 BACKUP_REGION、缺 BACKUP_ACCESS_KEY_ID、缺 BACKUP_SECRET_ACCESS_KEY、缺 BACKUP_ENCRYPTION_KEY", run.error_summary
  end

  test "重试沿用同一条记录：上一次的原因清掉" do
    stub_request(:put, %r{\A#{BUCKET}/}).to_return(status: 200)

    with_backup_config do
      run = BackupRun.create!(trigger: "scheduled", status: "queued", error_summary: "上传没有完成：Net::OpenTimeout")
      run.perform_now(attempt: 2)
      assert_equal "succeeded", run.status
      assert_nil run.error_summary
    end
  end

  test "create_later：建一条排队的记录并入队" do
    run = nil
    assert_enqueued_with(job: BackupJob) { run = BackupRun.create_later(trigger: "manual") }
    assert_equal [ "manual", "queued" ], [ run.trigger, run.status ]
    assert_enqueued_with(job: BackupJob, args: [ run ])
  end

  test "create_later：入队失败就删掉记录再抛出" do
    BackupJob.stubs(:perform_later).returns(false)

    assert_no_difference("BackupRun.count") do
      assert_raises(Backup::Error) { BackupRun.create_later(trigger: "scheduled") }
    end
  end

  test "进行中：排队或在跑，且 30 分钟内有动静；更久的算未完成" do
    fresh = BackupRun.create!(trigger: "manual", status: "running")
    stuck = BackupRun.create!(trigger: "scheduled", status: "queued", updated_at: 31.minutes.ago)
    BackupRun.create!(trigger: "scheduled", status: "succeeded")

    assert_equal [ fresh ], BackupRun.active.to_a
    assert_equal "进行中", fresh.status_label
    assert stuck.stalled?
    assert_equal "未完成", stuck.status_label
  end

  test "保留 30 天" do
    old = BackupRun.create!(trigger: "scheduled", status: "succeeded", created_at: 31.days.ago)
    recent = BackupRun.create!(trigger: "scheduled", status: "succeeded", created_at: 29.days.ago)

    BackupRun.cleanup
    assert_not BackupRun.exists?(old.id)
    assert BackupRun.exists?(recent.id)
  end
end
