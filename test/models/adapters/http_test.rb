require "test_helper"

class Adapters::HttpTest < ActiveSupport::TestCase
  setup { Surfguard.stubs(:resolve_public_ips).returns([ "93.184.216.34" ]) }

  test "带 User-Agent 取回正文" do
    stub_request(:get, "https://example.com/feed").with(headers: { "User-Agent" => /lowpass/ }).to_return(body: "<rss/>", status: 200)
    response = Adapters::Http.get("https://example.com/feed")
    assert_equal 200, response.status
    assert_equal "<rss/>", response.body
  end

  test "429 与 403 直接失败不重试" do
    stub_request(:get, "https://example.com/x").to_return(status: 429)
    assert_raises(Adapters::Http::Blocked) { Adapters::Http.get("https://example.com/x") }
    assert_requested :get, "https://example.com/x", times: 1
  end

  test "超过大小上限失败" do
    stub_request(:get, "https://example.com/big").to_return(body: "x" * 1000)
    assert_raises(Adapters::Http::TooLarge) { Adapters::Http.get("https://example.com/big", max_bytes: 100) }
  end

  test "解析不到公网地址时拒绝连接" do
    Surfguard.unstub(:resolve_public_ips)
    Surfguard.stubs(:resolve_public_ips).raises(Surfguard::Unresolvable)
    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http.get("http://10.0.0.1/feed") }
  end

  test "跟随重定向并对每一跳重新解析" do
    Surfguard.unstub(:resolve_public_ips)
    Surfguard.expects(:resolve_public_ips).twice.returns([ "93.184.216.34" ])
    stub_request(:get, "https://example.com/old").to_return(status: 302, headers: { "Location" => "https://example.com/new" })
    stub_request(:get, "https://example.com/new").to_return(body: "ok", status: 200)
    response = Adapters::Http.get("https://example.com/old")
    assert_equal "ok", response.body
    assert_requested :get, "https://example.com/old", times: 1
    assert_requested :get, "https://example.com/new", times: 1
  end

  test "重定向缺少 Location 报错" do
    stub_request(:get, "https://example.com/nowhere").to_return(status: 302)
    assert_raises(Adapters::Http::Error) { Adapters::Http.get("https://example.com/nowhere") }
  end

  test "连接超时映射为 Error" do
    stub_request(:get, "https://example.com/slow").to_timeout
    assert_raises(Adapters::Http::Error) { Adapters::Http.get("https://example.com/slow") }
  end

  test "地址格式非法映射为 Error" do
    assert_raises(Adapters::Http::Error) { Adapters::Http.get("http://exa mple.com/feed") }
  end

  # 响应头不归 max_bytes 管：恶意源站回一个没完没了的头，进程就会被撑爆
  test "一行响应头超长时失败" do
    serve_once("HTTP/1.1 200 OK\r\nX-Pad: #{"a" * 1.megabyte}\r\nContent-Length: 2\r\n\r\nok") do |url|
      assert_raises(Adapters::Http::TooLarge) { Adapters::Http.get(url, timeout: 5) }
    end
  end

  test "响应头行数过多时失败" do
    headers = Array.new(20_000) { |i| "X-Pad-#{i}: #{"a" * 32}\r\n" }.join
    serve_once("HTTP/1.1 200 OK\r\n#{headers}Content-Length: 2\r\n\r\nok") do |url|
      assert_raises(Adapters::Http::TooLarge) { Adapters::Http.get(url, timeout: 5) }
    end
  end

  test "真实连接照常读回 chunked 正文" do
    serve_once("HTTP/1.1 200 OK\r\nContent-Type: application/rss+xml\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n") do |url|
      response = Adapters::Http.get(url, timeout: 5)
      assert_equal "hello world", response.body
      assert_equal "application/rss+xml", response.content_type
    end
  end

  private
    # 读响应头那一层在 WebMock 之下，只能拿真连接测：本机起一个只答一次的服务，回写死的原始响应
    def serve_once(raw_response)
      Surfguard.stubs(:resolve_public_ips).returns([ "127.0.0.1" ])
      server = TCPServer.new("127.0.0.1", 0)
      thread = Thread.new do
        client = server.accept
        client.readpartial(4096)
        client.write(raw_response)
      rescue IOError, SystemCallError
        nil # 客户端读到上限就断开，这边写不完是预期的
      ensure
        client&.close
      end
      yield "http://127.0.0.1:#{server.addr[1]}/feed"
    ensure
      thread&.kill
      server&.close
    end
end
