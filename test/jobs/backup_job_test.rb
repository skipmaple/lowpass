require "test_helper"

class BackupJobTest < ActiveJob::TestCase
  setup { @run = BackupRun.create!(trigger: "scheduled", status: "queued") }

  test "成功：不告警" do
    BackupRun.any_instance.expects(:perform_now).with(attempt: 1)
    assert_no_difference("AlertEvent.count") { BackupJob.perform_now(@run) }
  end

  test "上传的暂时性故障：记录回到排队，2 分钟后再试，不告警" do
    BackupRun.any_instance.stubs(:perform_now).raises(Backup::Transient, "上传失败（503）")

    assert_no_difference("AlertEvent.count") do
      assert_enqueued_with(job: BackupJob, args: [ @run ], at: 2.minutes.from_now) { BackupJob.perform_now(@run) }
    end
    assert_equal "queued", @run.reload.status
  end

  test "第三次还不行：告警一次再抛出" do
    @run.update!(error_summary: "上传没有完成：Net::WriteTimeout")
    BackupRun.any_instance.stubs(:perform_now).raises(Backup::Transient, "上传没有完成：Net::WriteTimeout")
    job = BackupJob.new(@run)
    job.executions = 2
    # retry_on 的 attempts: 数的是 exception_executions（键是 retry_on 声明的异常数组原样 to_s），见 fetch_source_job_test
    job.exception_executions = { "[Backup::Transient]" => 2 }

    assert_difference("AlertEvent.where(kind: 'backup_failed').count", 1) { assert_raises(Backup::Transient) { job.perform_now } }
    event = AlertEvent.find_by!(kind: "backup_failed")
    assert_equal "critical", event.level
    assert_equal "上传没有完成：Net::WriteTimeout", event.summary
    assert_equal "/admin/settings", event.url_path
  end

  # perform_now 失败时已经把原因记在记录上（BackupRun#record_failure），告警用的就是那一句
  test "终态错误：立即告警，不重试" do
    @run.update!(status: "failed", error_summary: "pg_dump 失败：退出码 1")
    BackupRun.any_instance.stubs(:perform_now).raises(Backup::Error, "pg_dump 失败：退出码 1")

    assert_no_enqueued_jobs(only: BackupJob) do
      assert_difference("AlertEvent.where(kind: 'backup_failed').count", 1) { assert_raises(Backup::Error) { BackupJob.perform_now(@run) } }
    end
    assert_equal "pg_dump 失败：退出码 1", AlertEvent.find_by!(kind: "backup_failed").summary
  end

  test "记录上没有原因时，用异常本身的一句" do
    BackupRun.any_instance.stubs(:perform_now).raises(Errno::ENOSPC)
    assert_raises(Errno::ENOSPC) { BackupJob.perform_now(@run) }
    assert_equal "Errno::ENOSPC: No space left on device", AlertEvent.find_by!(kind: "backup_failed").summary
  end

  test "同一天再失败不重复告警（R-7.1）" do
    BackupRun.any_instance.stubs(:perform_now).raises(Backup::Error, "上传失败（403）：AccessDenied")
    assert_raises(Backup::Error) { BackupJob.perform_now(@run) }

    assert_no_difference("AlertEvent.count") { assert_raises(Backup::Error) { BackupJob.perform_now(BackupRun.create!(trigger: "manual", status: "queued")) } }
  end
end
