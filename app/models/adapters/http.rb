require "net/http"
require "openssl"
require "zlib"

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

    def self.get_prefix(url, timeout: 5, max_bytes: 128.kilobytes)
      new(timeout: timeout, max_bytes: max_bytes).get_prefix(url)
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
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_hostname = true
      http.ipaddr = ip
      http.extend(CappedLines)

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
    rescue Net::ReadLimitExceeded => e
      raise TooLarge, e.message
    rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, URI::Error, Zlib::Error => e
      raise Error, e.message
    end

    def get_prefix(url)
      raise ArgumentError, "max_bytes must be positive" unless @max_bytes.is_a?(Integer) && @max_bytes.positive?

      # 一个期限覆盖 DNS、连接、各跳重定向与正文，不能被慢速分块或重定向不断重置。
      Timeout.timeout(@timeout) { request_prefix(url) }
    rescue Net::ReadLimitExceeded => e
      raise TooLarge, e.message
    rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, URI::Error, Net::HTTPBadResponse, Zlib::Error => e
      raise Error, e.message
    end

    private
      def request_prefix(url, redirects = 0)
        uri = URI.parse(url)
        raise Error, "unsupported image URL" unless uri.is_a?(URI::HTTP) && uri.hostname.present? && uri.userinfo.nil?
        ip = resolve_public_ip(uri.hostname)

        http = Net::HTTP.new(uri.hostname, uri.port, nil)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        http.write_timeout = @timeout
        http.max_retries = 0
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_hostname = true
        http.ipaddr = ip
        http.extend(CappedLines)

        http.start do |conn|
          request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "*/*",
            "Accept-Encoding" => "identity", "Range" => "bytes=0-#{@max_bytes - 1}")
          conn.request(request) do |res|
            if res.is_a?(Net::HTTPRedirection)
              raise Error, "too many redirects" if redirects >= MAX_REDIRECTS
              location = res["Location"]
              raise Error, "redirect without Location" if location.blank?
              return request_prefix(URI.join(uri, location).to_s, redirects + 1)
            end
            raise Blocked, "#{res.code} for #{uri}" if res.code.in?(%w[ 403 429 ])
            raise Error, "#{res.code} for #{uri}" unless res.is_a?(Net::HTTPSuccess)

            # return 穿过 Net::HTTP 的 response block，跳过 reading_body 隐式补读剩余正文；
            # http.start 的 ensure 会关闭这条专用连接，源站无视 Range 也不会继续下载。
            return Response.new(res.code.to_i, read_prefix(res), res["Content-Type"])
          end
        end
      end

      def read_prefix(res)
        buffer = +"".b
        res.read_body do |chunk|
          buffer << chunk.byteslice(0, @max_bytes - buffer.bytesize).b
          return buffer if buffer.bytesize >= @max_bytes
        end
        buffer
      end

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
