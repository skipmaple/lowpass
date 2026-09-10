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
end
