require "test_helper"

class Admin::BackupsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "立即备份：建记录、入队、审计、提示" do
    with_backup_config do
      assert_enqueued_with(job: BackupJob) { post admin_backup_path }
      assert_redirected_to admin_settings_path
      assert_equal "已开始备份", flash[:notice]
      run = BackupRun.sole
      assert_equal [ "manual", "queued" ], [ run.trigger, run.status ]
      assert_equal "backup.create", AuditLog.sole.action
      assert_equal "BackupRun##{run.id}", AuditLog.sole.target
    end
  end

  test "没配好：不建记录" do
    assert_no_difference("BackupRun.count") { post admin_backup_path }
    assert_redirected_to admin_settings_path
    assert_equal "备份未配置", flash[:alert]
  end

  test "已有备份在进行：不再建" do
    with_backup_config do
      BackupRun.create!(trigger: "scheduled", status: "running")
      assert_no_difference("BackupRun.count") { post admin_backup_path }
      assert_equal "已有备份在进行", flash[:alert]
    end
  end

  # 进程在备份途中被杀留下的记录不该永远挡着按钮
  test "卡住的旧记录不挡" do
    with_backup_config do
      BackupRun.create!(trigger: "scheduled", status: "running", updated_at: 31.minutes.ago)
      assert_difference("BackupRun.count", 1) { post admin_backup_path }
      assert_equal "已开始备份", flash[:notice]
    end
  end

  test "入队失败：提示，不 500" do
    with_backup_config do
      BackupJob.stubs(:perform_later).returns(false)
      post admin_backup_path
      assert_redirected_to admin_settings_path
      assert_equal "备份没能入队", flash[:alert]
      assert_equal 0, AuditLog.count
    end
  end

  test "每分钟 5 次" do
    5.times { post admin_backup_path }
    post admin_backup_path
    assert_equal "操作过于频繁，请稍后再试。", flash[:alert]
  end

  test "成员 403" do
    sign_in_as(users(:guest))
    post admin_backup_path
    assert_response :forbidden
  end
end
