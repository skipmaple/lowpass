require "json"

module Adapters
  class Http
    # 本机代理的 fake-IP 不能作为公网地址放行。仅供开发显式启用：可信 DoH 取真实地址，
    # 仍由 Surfguard 拦截非公网地址，Http 再将通过检查的 IP 固定到连接上。
    class PublicDns
      HOST = "cloudflare-dns.com"
      ADDRESS = "1.1.1.1"
      MAX_BYTES = 64.kilobytes

      def self.resolve(host) = new(host).resolve

      def initialize(host)
        @host = host
      end

      def resolve
        raise Unresolvable unless @host.is_a?(String) && @host.valid_encoding? && @host.ascii_only?

        if numeric_host?
          Surfguard.resolve_public_ips(@host).first or raise Unresolvable, @host
        else
          @host = @host.delete_suffix(".").downcase
          raise Unresolvable, @host unless valid_name?

          addresses_from(query).first
        end
      rescue Surfguard::Unresolvable, JSON::ParserError, Net::ReadLimitExceeded, Timeout::Error,
        IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Zlib::Error
        raise Unresolvable, @host
      end

      private
        def numeric_host?
          @host.include?(":") || @host.delete_suffix(".").split(".", -1).all? { |part| part.match?(/\A(?:0[xX][0-9a-fA-F]+|[0-9]+)\z/) }
        end

        def valid_name?
          labels = @host.split(".", -1)
          @host.bytesize <= 253 && labels.length >= 2 && labels.all? do |label|
            label.bytesize <= 63 && label.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/)
          end
        end

        def query
          # 域名用于 TLS/SNI 与 Host 校验，固定公网 IP 用于连接；不使用代理或系统 DNS 引导解析器。
          http = Net::HTTP.new(HOST, 443, nil)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.verify_hostname = true
          http.ipaddr = ADDRESS
          http.open_timeout = 5
          http.read_timeout = 8
          http.write_timeout = 5
          http.max_retries = 0
          http.extend(CappedLines)
          path = "/dns-query?#{URI.encode_www_form(name: @host, type: "A")}"
          request = Net::HTTP::Get.new(path, "Accept" => "application/dns-json", "User-Agent" => USER_AGENT)

          http.start do |connection|
            connection.request(request) do |response|
              # 解析器地址固定：重定向、429、403 或错误响应都直接失败，不重试、不降级。
              raise Unresolvable, @host unless response.is_a?(Net::HTTPSuccess)

              body = +""
              response.read_body do |chunk|
                raise Unresolvable, @host if body.bytesize + chunk.bytesize > MAX_BYTES
                body << chunk
              end
              return JSON.parse(body)
            end
          end
        end

        def addresses_from(payload)
          raise Unresolvable, @host unless payload.is_a?(Hash) && payload["Status"] == 0 && payload["TC"] == false
          questions = payload["Question"]
          question = questions.first if questions.is_a?(Array) && questions.one?
          unless question.is_a?(Hash) && question["type"] == 1 && question["name"].is_a?(String) && question["name"].delete_suffix(".").downcase == @host
            raise Unresolvable, @host
          end

          answers = payload["Answer"]
          raise Unresolvable, @host unless answers.is_a?(Array) && answers.size <= 256 && answers.all? { |record| record.is_a?(Hash) }
          addresses = answers.select { |record| record["type"] == 1 }.map { |record| record["data"] }
          # 不从混合答案中挑「看起来安全」的一个；任一非公网或畸形 A 地址使整个回答失效。
          if addresses.empty? || addresses.any? { |ip| Surfguard.blocked_address?(ip) || !ip.match?(/\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/) }
            raise Unresolvable, @host
          end
          addresses.uniq
        end
    end
  end
end
