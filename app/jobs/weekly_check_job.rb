# R-2.1 每天一次的上游周刊检查：job 只负责入队，检查与装订都在模型里
class WeeklyCheckJob < ApplicationJob
  queue_as :default
  # 检查要挨个源出网，慢；同时跑两份会对同一节又替换又追加
  limits_concurrency to: 1, key: -> { "weekly_check" }, duration: 10.minutes

  def perform = Issue.check_weekly_sources!
end
