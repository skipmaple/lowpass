# Task 15 实现：检查上游周刊是否更新并生成本周周刊
class WeeklyCheckJob < ApplicationJob
  queue_as :default

  def perform; end
end
