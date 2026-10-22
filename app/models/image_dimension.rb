# 原图天然尺寸的独立展示缓存；刷新失败保留已经确认的占位，不改刊期与条目。
class ImageDimension < ApplicationRecord
  REFRESH_AFTER = 30.days
  RETRY_AFTER = 1.day
  QUEUE_LEASE = 10.minutes
  MAX_DIMENSION = 100_000
  MAX_URLS = 100
  MAX_JOBS = 10

  validates :url, presence: true, length: { maximum: 2048 }
  validates :url_hash, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :width, :height, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DIMENSION }, allow_nil: true
  validate :http_url

  class << self
    def for_urls(urls)
      hashes = valid_urls(urls).map { |url| Digest::SHA256.hexdigest(url) }
      where(url_hash: hashes).where.not(confirmed_at: nil).pluck(:url, :width, :height).to_h do |url, width, height|
        [ url, { width: width, height: height } ]
      end
    rescue ActiveRecord::ActiveRecordError => e
      report(e)
      {}
    end

    # 每次只登记一小批 URL；唯一索引处理多个 tick 同时发现同一个地址的竞争。
    def enqueue_for(urls, now: Time.current)
      enqueued = 0
      entries = valid_urls(urls).map { |url| { url: url, url_hash: Digest::SHA256.hexdigest(url) } }
      hashes = entries.pluck(:url_hash)
      known = where(url_hash: hashes).pluck(:url_hash).to_set
      missing = entries.reject { |entry| known.include?(entry[:url_hash]) }.first(MAX_URLS).map do |entry|
        entry.merge(id: Lowpass::Uuid.generate, created_at: now, updated_at: now)
      end
      insert_all(missing, unique_by: :url_hash) if missing.any?

      due(now).where(url_hash: hashes).order(:created_at, :id).limit(MAX_JOBS).each do |record|
        enqueued += 1 if record.send(:queue_if_due, now)
      end
      enqueued
    rescue ActiveRecord::ActiveRecordError => e
      report(e)
      enqueued
    end

    # 既刊回填与新周刊共用分钟 tick；只读最近五百条可见条目的元数据，不加载正文。
    def discover_later(now: Time.current)
      metadata = Item.visible.joins(:issue).merge(Issue.weekly.where(state: "published"))
        .order(Arel.sql("issues.published_at DESC NULLS LAST, items.rank ASC, items.id ASC"))
        .limit(500).pluck(:meta)
      urls = metadata.flat_map { |meta| meta["image_urls"].is_a?(Array) ? meta["image_urls"] : [] }
      enqueue_for(urls, now: now)
    rescue ActiveRecord::ActiveRecordError => e
      report(e)
      0
    end

    def due(now)
      where("confirmed_at IS NULL OR confirmed_at <= ?", now - REFRESH_AFTER)
        .where("retry_at IS NULL OR retry_at <= ?", now)
        .where("queued_at IS NULL OR queued_at <= ?", now - QUEUE_LEASE)
    end

    private
      def valid_urls(urls)
        Array(urls).select { |url| valid_url?(url) }.uniq
      end

      def valid_url?(url)
        if url.is_a?(String) && url.length.between?(1, 2048)
          uri = URI.parse(url)
          uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
        else
          false
        end
      rescue URI::InvalidURIError
        false
      end

      def report(error)
        Rails.error.report(error, handled: true, context: { cache: "image_dimensions" })
      end
  end

  # 队列按 URL 串行；再次执行旧任务先重读缓存，避免已经成功或处于退避期时重复出站。
  def probe_now(now: Time.current)
    reload
    return if (confirmed_at && confirmed_at > now - REFRESH_AFTER) || (retry_at && retry_at > now)

    response = Adapters::Http.get_prefix(url, timeout: 5, max_bytes: 128.kilobytes)
    if dimensions = Header.parse(response.body)
      update!(width: dimensions.first, height: dimensions.last, confirmed_at: now, retry_at: nil, queued_at: nil)
    else
      record_failure(now)
    end
  rescue StandardError => e
    record_failure(now)
    self.class.send(:report, e)
  end

  private
    # 条件 UPDATE 是短暂的数据库认领；入队与后续网络请求都不持有行锁。
    def queue_if_due(now)
      claimed = self.class.due(now).where(id: id).update_all(queued_at: now, updated_at: now).positive?
      return false unless claimed

      enqueued = ProbeImageDimensionJob.perform_later(self)
      !!enqueued
    rescue StandardError => e
      self.class.send(:report, e)
      false
    ensure
      if claimed && !enqueued
        self.class.where(id: id, queued_at: now).update_all(queued_at: nil, updated_at: now)
      end
    end

    def record_failure(now)
      update!(retry_at: now + RETRY_AFTER, queued_at: nil)
    rescue ActiveRecord::ActiveRecordError => e
      self.class.send(:report, e)
    end

    def http_url
      errors.add(:url, :invalid) unless self.class.send(:valid_url?, url)
    end
end
