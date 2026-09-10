class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # 记录已经不在了就没有可做的事：源被删掉、期被清掉之后，排队里的旧任务直接丢弃，
  # 不要一路重试到失败队列里
  discard_on ActiveJob::DeserializationError
end
