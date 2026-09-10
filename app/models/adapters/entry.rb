module Adapters
  Entry = Struct.new(:title, :url, :summary, :section, :author, :published_at, :rank, :meta, keyword_init: true) do
    def valid?
      title.to_s.strip.present? && http_url? && url.to_s.strip.length <= 2048
    end

    def to_item_attributes(source:, issue:)
      {
        source_id: source.id,
        issue_id: issue.id,
        title: title.to_s.strip[0, 300],
        url: url.to_s.strip[0, 2048],
        url_hash: UrlNormalizer.url_hash(url),
        summary: SummaryCleaner.clean(summary),
        section: section&.strip&.slice(0, 100),
        author: author&.strip&.slice(0, 100),
        published_at: published_at,
        rank: rank,
        meta: meta || {},
        fetched_at: Time.current
      }
    end

    private
      def http_url?
        uri = URI.parse(url.to_s.strip)
        uri.is_a?(URI::HTTP) && uri.host.present?
      rescue URI::InvalidURIError
        false
      end
  end
end
