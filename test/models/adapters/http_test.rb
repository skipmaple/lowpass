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

  test "前缀请求带 Range identity 和 User-Agent 并返回二进制" do
    stub_request(:get, "https://example.com/image").with(headers: {
      "Range" => "bytes=0-127", "Accept-Encoding" => "identity", "User-Agent" => /lowpass/
    }).to_return(status: 206, body: "\xff\xd8\xff".b, headers: { "Content-Type" => "image/jpeg" })
    response = Adapters::Http.get_prefix("https://example.com/image", max_bytes: 128)
    assert_equal 206, response.status
    assert_equal "\xff\xd8\xff".b, response.body
    assert_equal Encoding::ASCII_8BIT, response.body.encoding
    assert_equal "image/jpeg", response.content_type
  end

  test "源站无视 Range 时只返回前缀 不因完整正文过大报错" do
    stub_request(:get, "https://example.com/image").to_return(body: "x" * 1000, headers: { "Content-Length" => "1000" })
    assert_equal "x" * 128, Adapters::Http.get_prefix("https://example.com/image", max_bytes: 128).body
  end

  test "前缀按字节截断 UTF8 响应且始终返回二进制编码" do
    stub_request(:get, "https://example.com/image").to_return(body: "图片")
    response = Adapters::Http.get_prefix("https://example.com/image", max_bytes: 4)
    assert_equal "\xe5\x9b\xbe\xe7".b, response.body
    assert_equal Encoding::ASCII_8BIT, response.body.encoding
  end

  test "无视 Range 的真实连接发完前缀后立即被关闭而不是继续读正文" do
    serve_prefix do |url, disconnected|
      response = Adapters::Http.get_prefix(url, timeout: 0.5, max_bytes: 128)
      assert_equal "x" * 128, response.body
      assert Timeout.timeout(1) { disconnected.pop }, "源站没有观察到连接关闭"
    end
  end

  test "前缀请求对各跳检查公网地址且最多跟随三跳" do
    Surfguard.expects(:resolve_public_ips).with("example.com").times(4).returns([ "93.184.216.34" ])
    (0..3).each do |number|
      stub_request(:get, "https://example.com/#{number}").to_return(status: 302, headers: { "Location" => "/#{number + 1}" })
    end
    assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix("https://example.com/0") }
    assert_not_requested :get, "https://example.com/4"
  end

  test "前缀请求拒绝重定向到私网和缺少目标的重定向" do
    Surfguard.stubs(:resolve_public_ips).with("internal.example").raises(Surfguard::Unresolvable)
    stub_request(:get, "https://example.com/image").to_return(status: 302, headers: { "Location" => "http://internal.example/image" })
    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http.get_prefix("https://example.com/image") }
    assert_not_requested :get, "http://internal.example/image"
    stub_request(:get, "https://example.com/missing").to_return(status: 302)
    assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix("https://example.com/missing") }
  end

  test "前缀请求拒绝非 HTTP 和内嵌用户名密码" do
    [ "file:///tmp/image", "ftp://example.com/image", "https://user:secret@example.com/image", "https://user@example.com/image", "http://exa mple.com/image" ].each do |url|
      assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix(url) }
    end
  end

  test "前缀请求的 403 429 和连接失败均不重试" do
    [ 403, 429 ].each do |status|
      stub_request(:get, "https://example.com/#{status}").to_return(status: status)
      assert_raises(Adapters::Http::Blocked) { Adapters::Http.get_prefix("https://example.com/#{status}") }
      assert_requested :get, "https://example.com/#{status}", times: 1
    end
    stub_request(:get, "https://example.com/timeout").to_timeout
    assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix("https://example.com/timeout") }
    assert_requested :get, "https://example.com/timeout", times: 1
  end

  test "真实连接在收到响应前被关闭也不触发 Net HTTP 隐式重试" do
    serve_without_response do |url, connections|
      assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix(url, timeout: 0.5) }
      assert_equal 1, connections.size
    end
  end

  test "持续有字节的慢正文也受整个请求的期限限制" do
    serve_prefix(trickle: true) do |url, _disconnected|
      assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix(url, timeout: 0.05, max_bytes: 128) }
    end
  end

  test "前缀总超时包含重定向的解析和响应时间" do
    Surfguard.stubs(:resolve_public_ips).with("example.com").returns([ "93.184.216.34" ])
    Surfguard.stubs(:resolve_public_ips).with do |host|
      if host == "slow.example"
        sleep 0.2
        true
      else
        false
      end
    end.returns([ "93.184.216.34" ])
    stub_request(:get, "https://example.com/image").to_return(status: 302, headers: { "Location" => "https://slow.example/image" })
    stub_request(:get, "https://slow.example/image").to_return(body: "image")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(Adapters::Http::Error) { Adapters::Http.get_prefix("https://example.com/image", timeout: 0.05) }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 0.18
    assert_requested :get, "https://example.com/image", times: 1
    assert_not_requested :get, "https://slow.example/image"
  end

  test "前缀请求仍限制超长响应头和 chunked 分块长度行" do
    serve_once("HTTP/1.1 200 OK\r\nX-Pad: #{"a" * 1.megabyte}\r\nContent-Length: 2\r\n\r\nok") do |url|
      assert_raises(Adapters::Http::TooLarge) { Adapters::Http.get_prefix(url) }
    end
    serve_once("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n#{"0" * 1.megabyte}1\r\nx\r\n0\r\n\r\n") do |url|
      assert_raises(Adapters::Http::TooLarge) { Adapters::Http.get_prefix(url) }
    end
  end

  private
    def serve_prefix(trickle: false)
      # WebMock 的 allow_localhost 分支会在调用 response block 前缓存完整正文；
      # 这条测试必须直连本机 TCP，才能验证客户端确实中止下载。
      WebMock.disable!
      Surfguard.stubs(:resolve_public_ips).returns([ "127.0.0.1" ])
      server = TCPServer.new("127.0.0.1", 0)
      disconnected = Queue.new
      thread = Thread.new do
        client = server.accept
        client.readpartial(4096)
        client.write("HTTP/1.1 200 OK\r\nContent-Length: 10000000\r\n\r\n")
        if trickle
          128.times do
            client.write("x")
            sleep 0.01
          end
        else
          client.write("x" * 128)
        end
        disconnected << client.read.empty?
      rescue IOError, SystemCallError
        disconnected << true
      ensure
        client&.close
      end
      yield "http://127.0.0.1:#{server.addr[1]}/image", disconnected
    ensure
      thread&.kill
      server&.close
      WebMock.enable!
    end

    def serve_without_response
      WebMock.disable!
      Surfguard.stubs(:resolve_public_ips).returns([ "127.0.0.1" ])
      server = TCPServer.new("127.0.0.1", 0)
      connections = Queue.new
      thread = Thread.new do
        client = nil
        loop do
          client = server.accept
          connections << true
          client.readpartial(4096)
          client.close
        end
      ensure
        client&.close
      end
      yield "http://127.0.0.1:#{server.addr[1]}/image", connections
    ensure
      thread&.kill
      server&.close
      WebMock.enable!
    end

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
