# R-2.1 每天一次的上游周刊检查：job 只负责入队，检查与装订都在模型里
class WeeklyCheckJob < ApplicationJob
  queue_as :default

  def perform = Issue.check_weekly_sources!
end
