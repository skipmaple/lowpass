class Source < ApplicationRecord
  include Source::Fetching

  ADAPTERS = %w[ hacker_news github_trending rss ruanyf_weekly ].freeze
  ADAPTER_LABELS = { "hacker_news" => "Hacker News", "github_trending" => "GitHub Trending", "rss" => "RSS/Atom", "ruanyf_weekly" => "阮一峰周刊" }.freeze

  # 栏尾「去源站看完整榜单」的落点（PRD 6.2）。榜单类源有固定地址，RSS 源回到 feed 的站点根。
  HOME_URLS = {
    "hacker_news" => "https://news.ycombinator.com/",
    "github_trending" => "https://github.com/trending",
    "ruanyf_weekly" => "https://github.com/ruanyf/weekly"
  }.freeze

  has_many :items, dependent: :restrict_with_exception
  has_many :fetch_runs, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { message: "名称已存在" }
  validates :adapter, inclusion: { in: ADAPTERS }
  validates :publication, inclusion: { in: %w[ daily weekly ] }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # 配置按适配器的模式归一与校验（R-3.2）；刊物与适配器绑定；RSS 的 feed 同刊物唯一（R-3.8）
  before_validation :normalize_config
  validate :publication_allowed, :config_conforms, :feed_url_unique

  scope :enabled, -> { where(enabled: true) }
  scope :daily,   -> { where(publication: "daily") }
  scope :weekly,  -> { where(publication: "weekly") }
  scope :ordered, -> { order(:sort_order, :name) }

  def adapter_class
    "Adapters::#{adapter.camelize}".constantize
  end

  def schema
    Source::Config.for(adapter)
  end

  def adapter_label
    ADAPTER_LABELS.fetch(adapter)
  end

  def home_url
    HOME_URLS[adapter] || feed_home_url
  end

  private
    def normalize_config
      self.config = schema.normalize(config, publication) if ADAPTERS.include?(adapter) && publication.present?
    end

    def publication_allowed
      if ADAPTERS.include?(adapter) && publication.present? && !schema.publications.include?(publication)
        errors.add(:publication, "这个适配器只能是#{schema.publications.first == "daily" ? "日刊" : "周刊"}")
      end
    end

    def config_conforms
      schema.validate(config, publication, errors) if ADAPTERS.include?(adapter) && schema.publications.include?(publication.to_s)
    end

    def feed_url_unique
      url = config["feed_url"]
      if adapter == "rss" && url.present? && Source.where(adapter: "rss", publication: publication).where("config->>'feed_url' = ?", url).where.not(id: id).exists?
        errors.add(:"config.feed_url", "这个 feed 地址已经在同一刊物里")
      end
    end

    # feed 地址不是 http(s)（配错了、写成裸域名、写成 file:）就没有栏尾外链可去：
    # 返回 nil，页面把整条外链收掉，而不是渲染一个点不开的链接。
    def feed_home_url
      uri = URI.parse(config["feed_url"].to_s)
      "#{uri.scheme}://#{uri.host}/" if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end
end
