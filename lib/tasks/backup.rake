namespace :backup do
  desc "马上备份一次（同步，不经队列）：数据库升级等高风险操作之前用；见 docs/development.md「备份」"
  task now: :environment do
    run = BackupRun.create!(trigger: "manual", status: "queued")
    begin
      run.perform_now
      puts "已上传 #{run.object_key}（#{ActiveSupport::NumberHelper.number_to_human_size(run.size_bytes)}）"
    rescue StandardError => e
      abort "备份失败：#{run.error_summary.presence || Backup.summary(e)}"
    end
  end
end
