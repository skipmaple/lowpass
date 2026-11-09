require "test_helper"

class Adapters::Http::PublicDnsTest < ActiveSupport::TestCase
  ENDPOINT = "https://cloudflare-dns.com/dns-query?name=example.com&type=A"

  test "固定可信解析器地址并验证 TLS，只发 A 查询且带 User-Agent" do
    connection = Net::HTTP.new("cloudflare-dns.com", 443, nil)
    Net::HTTP.expects(:new).with("cloudflare-dns.com", 443, nil).returns(connection)
    stub_request(:get, ENDPOINT).with(headers: { "Accept" => "application/dns-json", "User-Agent" => Adapters::Http::USER_AGENT })
      .to_return(body: answer("93.184.216.34"))

    assert_equal "93.184.216.34", Adapters::Http::PublicDns.resolve("example.com")
    assert_equal "1.1.1.1", connection.ipaddr
    assert connection.use_ssl?
    assert_equal OpenSSL::SSL::VERIFY_PEER, connection.verify_mode
    assert connection.verify_hostname
    assert_not connection.proxy?
    assert_equal 5, connection.open_timeout
    assert_equal 8, connection.read_timeout
    assert_equal 0, connection.max_retries
    assert_requested :get, ENDPOINT, times: 1
  end

  test "任一 A 答案为私网、fake-IP 或畸形地址时整组拒绝" do
    %w[127.0.0.1 10.0.0.1 169.254.169.254 198.18.0.86 ::ffff:93.184.216.34 999.1.1.1 93.184.216.34/24].each do |blocked|
      stub_request(:get, ENDPOINT).to_return(body: answer("93.184.216.34", blocked))

      assert_raises(Adapters::Http::Unresolvable, blocked) { Adapters::Http::PublicDns.resolve("example.com") }
    end
  end

  test "数值地址交给原 Surfguard，绝不送外部 DNS" do
    Resolv.expects(:getaddresses).never
    assert_equal "93.184.216.34", Adapters::Http::PublicDns.resolve("93.184.216.34")
    # 非规范 IPv4 在 libc 上存在八进制／十进制分歧；一律拒绝，不让平台决定目的地。
    %w[0177.0.0.1 093.184.216.34 93.184.216.034 93.184.216.34. 127.0.0.1 169.254.169.254 198.18.0.86 ::1 ::ffff:127.0.0.1 2130706433 0x7f000001].each do |blocked|
      assert_raises(Adapters::Http::Unresolvable, blocked) { Adapters::Http::PublicDns.resolve(blocked) }
    end
    assert_not_requested :get, /cloudflare-dns\.com/
  end

  test "无效 DNS 名和单标签本地名不会发出查询" do
    [ nil, "", "localhost", "ex ample.com", "foo..com", "-foo.com", "foo_.com", "a" * 64 + ".com", "example.com\n", "example.com?name=private" ].each do |host|
      assert_raises(Adapters::Http::Unresolvable, host.inspect) { Adapters::Http::PublicDns.resolve(host) }
    end
    assert_not_requested :get, /cloudflare-dns\.com/
  end

  test "域名大小写和绝对域名归一化后查询" do
    stub_request(:get, ENDPOINT).to_return(body: answer("93.184.216.34"))

    assert_equal "93.184.216.34", Adapters::Http::PublicDns.resolve("EXAMPLE.COM.")
  end

  test "解析器响应超过上限直接拒绝" do
    stub_request(:get, ENDPOINT).to_return(body: " " * (64.kilobytes + 1))

    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http::PublicDns.resolve("example.com") }
  end

  test "DNS 错误、截断、不匹配问题和无 A 答案均不接受" do
    valid = JSON.parse(answer("93.184.216.34"))
    [ valid.merge("Status" => 3), valid.merge("TC" => true), valid.merge("Question" => [ { "name" => "elsewhere.com", "type" => 1 } ]),
      valid.merge("Answer" => []), valid.merge("Answer" => [ { "type" => 28, "data" => "2606:4700:4700::1111" } ]),
      valid.merge("Answer" => "bad"), [], nil ].each do |payload|
      stub_request(:get, ENDPOINT).to_return(body: payload.to_json)

      assert_raises(Adapters::Http::Unresolvable) { Adapters::Http::PublicDns.resolve("example.com") }
    end
    stub_request(:get, ENDPOINT).to_return(body: "not json")
    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http::PublicDns.resolve("example.com") }
  end

  test "解析器不跟随重定向，也不重试限流或服务端错误" do
    [ 302, 403, 429, 500 ].each do |status|
      stub_request(:get, ENDPOINT).to_return(status: status, headers: { "Location" => "http://127.0.0.1/private" })

      assert_raises(Adapters::Http::Unresolvable) { Adapters::Http::PublicDns.resolve("example.com") }
    end
    assert_requested :get, ENDPOINT, times: 4
    assert_not_requested :get, "http://127.0.0.1/private"
  end

  test "TLS 错误和连接超时不回退到系统 DNS 或不安全连接" do
    Resolv.expects(:getaddresses).never
    stub_request(:get, ENDPOINT).to_raise(OpenSSL::SSL::SSLError.new("certificate verify failed"))
    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http::PublicDns.resolve("example.com") }
    stub_request(:get, ENDPOINT).to_timeout
    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http::PublicDns.resolve("example.com") }
    assert_requested :get, ENDPOINT, times: 2
  end

  private
    def answer(*addresses)
      { Status: 0, TC: false, Question: [ { name: "example.com.", type: 1 } ],
        Answer: addresses.map { |ip| { name: "example.com.", type: 1, TTL: 60, data: ip } } }.to_json
    end
end
