require "ipaddr"

# 线上域名开着 Cloudflare 代理（橙云），kamal-proxy 开了 ssl 就不转发访客带来的 X-Forwarded-For，只把自己的对端
# （Cloudflare 节点）报给应用，于是 request.remote_ip 是节点 IP：登录回调限流（R-5.9）与 /health 的限流
# 都按节点算，同一节点背后的访客互相连累。对端确实是 Cloudflare 节点时，改用 Cloudflare 填的 CF-Connecting-IP；
# 源站 IP 不是秘密，直连源站的人自己带这个头时对端不是 Cloudflare，照旧按对端算。
module Cloudflare
  class ClientIp
    # https://www.cloudflare.com/ips/（2026-10-01 取），Cloudflare 增减网段时同步改
    RANGES = %w[
      173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18
      190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
      104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
      2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
    ].map { |range| IPAddr.new(range) }.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if (client = request.get_header("HTTP_CF_CONNECTING_IP").presence) && from_edge?(request)
        request.set_header("action_dispatch.remote_ip", client)
      end
      @app.call(env)
    end

    private
      def from_edge?(request)
        address = IPAddr.new(request.remote_ip)
        RANGES.any? { |range| range.include?(address) }
      rescue IPAddr::Error
        false
      end
  end
end
