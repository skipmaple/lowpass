class SchedulerTickJob < ApplicationJob
  queue_as :default

  def perform = Scheduler.tick
end
