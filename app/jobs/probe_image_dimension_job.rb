# 尺寸失败由缓存记录退避；403 / 429 与解析失败都不做 Active Job 的即时重试。
class ProbeImageDimensionJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(dimension) { dimension.url_hash }, duration: 10.minutes

  def perform(dimension)
    dimension.probe_now
  end
end
