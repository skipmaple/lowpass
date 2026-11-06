require "application_system_test_case"
require "socket"

class SystemWaitTest < ActiveSupport::TestCase
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6r9sAAAAASUVORK5CYII=".freeze

  test "execute 等待超时后截图和窗口命令仍收到各自的响应" do
    fixture = WebDriverFixture.new
    http = Selenium::WebDriver::Remote::Http::Default.new(
      client_config: Selenium::WebDriver::ClientConfig.new(
        server_url: "http://127.0.0.1:#{fixture.port}/", open_timeout: 2, read_timeout: 7
      )
    )
    bridge = Selenium::WebDriver::Remote::Bridge.new(http_client: http)
    bridge.create_session("browserName" => "protocol-fixture")
    driver = Selenium::WebDriver::Driver.new(bridge: bridge)

    # 用真实 helper 的五秒预算打断实际 HTTP read；原生 read timeout 仅作夹具保护。
    error = assert_raises(Timeout::Error) do
      ApplicationSystemTestCase.allocate.wait_until { driver.execute_script("return window.scrollY") == 137 }
    end
    assert_instance_of Timeout::Error, error
    fixture.release_response

    assert_equal PNG, driver.screenshot_as(:base64)
    assert_equal [ "fixture-window" ], driver.window_handles
    assert_equal PNG.unpack1("m"), driver.screenshot_as(:png)
    assert_equal [ 1, 2 ], fixture.request_connections.uniq
    assert_equal [ 2, 2, 2 ], fixture.request_connections.last(3)
  ensure
    http&.close
    fixture&.stop
  end

  private
    # 只监听 loopback，保留 HTTP keep-alive；新连接独立处理，不等旧响应排空。
    class WebDriverFixture
      attr_reader :port

      def initialize
        @server = TCPServer.new("127.0.0.1", 0)
        @port = @server.addr[1]
        @release = Queue.new
        @mutex = Mutex.new
        @sockets, @workers, @requests = [], [], []
        @stopped = false
        @acceptor = Thread.new do
          loop do
            socket = @server.accept
            @mutex.synchronize do
              @sockets << socket
              connection = @sockets.length
              @workers << Thread.new { serve(socket, connection) }
            end
          end
        rescue IOError, Errno::EBADF
          raise unless @stopped
        end
      end

      def release_response
        @release << true
      end

      def request_connections
        @mutex.synchronize { @requests.dup }
      end

      def stop
        @stopped = true
        release_response
        @server.close
        @acceptor.join
        @sockets.each { |socket| socket.close unless socket.closed? }
        @workers.each(&:join)
      end

      private
        def serve(socket, connection)
          while (line = socket.gets("\r\n"))
            _method, path = line.split
            headers = {}
            while (header = socket.gets("\r\n")) && header != "\r\n"
              name, value = header.split(":", 2)
              headers[name.downcase] = value.strip
            end
            socket.read(Integer(headers.fetch("content-length", "0")))
            @mutex.synchronize { @requests << connection }

            value = case path
            when "/session"
              { sessionId: "fixture-session", capabilities: { browserName: "protocol-fixture" } }
            when "/session/fixture-session/execute/sync"
              # 先保持连接活跃再阻塞：若第一条请求就阻塞五秒，默认两秒的
              # keep-alive 到期重连会掩盖未读响应，无法覆盖真实轮询的情况。
              @first_execute_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
              if Process.clock_gettime(Process::CLOCK_MONOTONIC) - @first_execute_at >= 4
                @release.pop
                137
              else
                0
              end
            when "/session/fixture-session/screenshot"
              PNG
            when "/session/fixture-session/window/handles"
              [ "fixture-window" ]
            else
              raise "Unexpected WebDriver fixture path: #{path}"
            end
            body = JSON.generate(value: value)
            socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: keep-alive\r\n\r\n#{body}")
          end
        rescue IOError, Errno::ECONNRESET, Errno::EPIPE
          # 超时关闭旧客户端连接、ensure 停止服务时都可能打断 read/write。
        ensure
          socket.close unless socket.closed?
        end
    end
end
