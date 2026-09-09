require "digest"

class UrlNormalizer
  TRACKING = /\A(utm_|ref\z|source\z|spm\z|fbclid\z|gclid\z)/i

  class << self
    def normalize(url)
      uri = URI.parse(url.strip)
      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.port = nil if uri.port == uri.default_port
      uri.fragment = nil
      uri.query = sorted_query(uri.query)
      uri.path = uri.path.chomp("/") if uri.path.length > 1
      uri.path = "/" if uri.path.empty?
      uri.to_s
    end

    def hash(url)
      canonical = normalize(url).sub(/\Ahttp:/, "https:")
      Digest::SHA256.hexdigest(canonical)
    end

    private
      def sorted_query(query)
        return nil if query.blank?
        pairs = URI.decode_www_form(query).reject { |k, _| k.match?(TRACKING) }.sort_by(&:first)
        pairs.empty? ? nil : URI.encode_www_form(pairs)
      end
  end
end
