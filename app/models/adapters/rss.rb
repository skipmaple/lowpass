require "rss"

module Adapters
  class Rss < Base
    ParseError = Class.new(StandardError)

    private
      def entries(period_key:)
        feed = parse_feed(http(config.fetch(:feed_url)).body)
        fetched_at = Time.current
        all = feed_items(feed).map { |it| normalize(it, fetched_at) }.select(&:valid?)
        window = if period_key
          range = PeriodKey.week_range(period_key)
          all.select { |e| range.cover?(e.published_at.in_time_zone(PeriodKey::ZONE).to_date) }
        else
          all.select { |e| e.published_at >= config.fetch(:window_hours, 24).to_i.hours.ago }
        end
        window.sort_by(&:published_at).reverse.first(config.fetch(:count, 10).to_i).each_with_index.map { |e, i| e.rank = i + 1; e }
      end

      def parse_feed(body)
        feed = ::RSS::Parser.parse(body, false)
        raise ParseError, "not a feed" if feed.nil?
        feed
      rescue ::RSS::Error => e
        raise ParseError, e.message
      end

      def feed_items(feed)
        feed.is_a?(::RSS::Atom::Feed) ? feed.entries : feed.items
      end

      def normalize(item, fetched_at)
        atom = item.respond_to?(:updated)
        published = atom ? (item.published&.content || item.updated&.content) : (item.pubDate || item.dc_date)
        Entry.new(
          title: atom ? item.title&.content : item.title,
          url: atom ? item.link&.href : item.link,
          summary: atom ? (item.summary&.content || item.content&.content) : (item.description.presence || item.content_encoded),
          author: atom ? item.author&.name&.content : (item.dc_creator || item.author),
          published_at: published&.to_time&.utc || fetched_at,
          meta: { image_url: first_image(item), time_from_fetch: published.nil? }.compact
        )
      end

      def first_image(item)
        html = (item.respond_to?(:content_encoded) ? item.content_encoded : item.try(:content)&.content).to_s
        Nokogiri::HTML.fragment(html).at_css("img")&.[]("src")
      end
  end
end
