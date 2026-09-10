class SchedulerTickJob < ApplicationJob
  queue_as :default
  # 每分钟一个 tick：上一次还没走完就不要再叠一个。补跑的判断读的是库里的状态，
  # 两个 tick 撞在一起会重复建期（撞唯一索引）、重复入队周刊检查。
  limits_concurrency to: 1, key: -> { "scheduler" }, duration: 5.minutes

  def perform = Scheduler.tick
end
