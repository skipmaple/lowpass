class Source < ApplicationRecord
  include Source::Fetching

  ADAPTERS = %w[ hacker_news github_trending rss ruanyf_weekly ].freeze

  # 栏尾「去源站看完整榜单」的落点（PRD 6.2）。榜单类源有固定地址，RSS 源回到 feed 的站点根。
  HOME_URLS = {
    "hacker_news" => "https://news.ycombinator.com/",
    "github_trending" => "https://github.com/trending",
    "ruanyf_weekly" => "https://github.com/ruanyf/weekly"
  }.freeze

  has_many :items, dependent: :restrict_with_exception
  has_many :fetch_runs, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }
  validates :adapter, inclusion: { in: ADAPTERS }
  validates :publication, inclusion: { in: %w[ daily weekly ] }

  scope :enabled, -> { where(enabled: true) }
  scope :daily,   -> { where(publication: "daily") }
  scope :weekly,  -> { where(publication: "weekly") }
  scope :ordered, -> { order(:sort_order, :name) }

  def adapter_class
    "Adapters::#{adapter.camelize}".constantize
  end

  def home_url
    HOME_URLS[adapter] || feed_home_url
  end

  private
    # feed 地址不是 http(s)（配错了、写成裸域名、写成 file:）就没有栏尾外链可去：
    # 返回 nil，页面把整条外链收掉，而不是渲染一个点不开的链接。
    def feed_home_url
      uri = URI.parse(config["feed_url"].to_s)
      "#{uri.scheme}://#{uri.host}/" if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end
end
