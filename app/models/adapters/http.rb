require "net/http"
require "openssl"

module Adapters
  class Http
    Error = Class.new(StandardError)
    Blocked = Class.new(Error)
    TooLarge = Class.new(Error)
    Unresolvable = Class.new(Error)
    Response = Struct.new(:status, :body, :content_type)

    USER_AGENT = "lowpass/0.1 (+#{ENV.fetch("BASE_URL", "https://lowpass.example")})"
    MAX_REDIRECTS = 3

    def self.get(url, timeout: 60, max_bytes: 2.megabytes)
      new(timeout: timeout, max_bytes: max_bytes).get(url)
    end

    def initialize(timeout:, max_bytes:)
      @timeout = timeout
      @max_bytes = max_bytes
    end

    def get(url, redirects = 0)
      uri = URI.parse(url)
      raise Error, "unsupported scheme" unless uri.is_a?(URI::HTTP)
      ip = resolve_public_ip(uri.hostname)

      http = Net::HTTP.new(uri.hostname, uri.port, nil)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = @timeout
      http.max_retries = 0
      http.ipaddr = ip

      http.start do |conn|
        request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "*/*")
        conn.request(request) do |res|
          return follow(res, redirects) if res.is_a?(Net::HTTPRedirection)
          raise Blocked, "#{res.code} for #{uri}" if res.code.in?(%w[ 403 429 ])
          raise Error, "#{res.code} for #{uri}" unless res.is_a?(Net::HTTPSuccess)
          body = read_capped(res)
          return Response.new(res.code.to_i, body, res["Content-Type"])
        end
      end
    rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, e.message
    end

    private
      def resolve_public_ip(host)
        Surfguard.resolve_public_ips(host).first or raise Unresolvable, host
      rescue Surfguard::Unresolvable
        raise Unresolvable, host
      end

      def follow(res, redirects)
        raise Error, "too many redirects" if redirects >= MAX_REDIRECTS
        location = res["Location"]
        raise Error, "redirect without Location" if location.blank?
        get(URI.join(res.uri, location).to_s, redirects + 1)
      end

      def read_capped(res)
        buffer = +""
        res.read_body do |chunk|
          buffer << chunk
          raise TooLarge, buffer.bytesize if buffer.bytesize > @max_bytes
        end
        buffer.force_encoding(Encoding::UTF_8)
      end
  end
end
