require "test_helper"

class Adapters::Http::DevelopmentDnsTest < ActiveSupport::TestCase
  setup do
    @previous_dns = ENV["DEV_PUBLIC_DNS"]
    ENV["DEV_PUBLIC_DNS"] = "cloudflare"
  end

  teardown { ENV["DEV_PUBLIC_DNS"] = @previous_dns }

  test "显式启用的开发 DNS 结果固定到源站连接，仍验证源站 TLS" do
    Rails.env.stubs(:development?).returns(true)
    Surfguard.expects(:resolve_public_ips).never
    Adapters::Http::PublicDns.expects(:resolve).with("example.com").returns("93.184.216.34")
    connection = Net::HTTP.new("example.com", 443, nil)
    Net::HTTP.expects(:new).with("example.com", 443, nil).returns(connection)
    stub_request(:get, "https://example.com/feed").to_return(body: "ok")

    assert_equal "ok", Adapters::Http.get("https://example.com/feed").body
    assert_equal "93.184.216.34", connection.ipaddr
    assert_equal OpenSSL::SSL::VERIFY_PEER, connection.verify_mode
    assert connection.verify_hostname
    assert_not connection.proxy?
  end

  test "非开发环境即使开关开启也沿用 Surfguard 系统解析" do
    Rails.env.stubs(:development?).returns(false)
    Adapters::Http::PublicDns.expects(:resolve).never
    Surfguard.expects(:resolve_public_ips).with("example.com").returns([ "93.184.216.34" ])
    stub_request(:get, "https://example.com/feed").to_return(body: "ok")

    assert_equal "ok", Adapters::Http.get("https://example.com/feed").body
  end

  test "开发环境未明确配置 cloudflare 时不用外部解析器" do
    Rails.env.stubs(:development?).returns(true)
    Adapters::Http::PublicDns.expects(:resolve).never
    Surfguard.expects(:resolve_public_ips).with("example.com").twice.returns([ "93.184.216.34" ])
    stub_request(:get, "https://example.com/feed").to_return(body: "ok")

    [ nil, "https://untrusted.example" ].each do |value|
      ENV["DEV_PUBLIC_DNS"] = value
      assert_equal "ok", Adapters::Http.get("https://example.com/feed").body
    end
  end

  test "源站重定向的每一跳仍须重新检查，不能转向私网" do
    Rails.env.stubs(:development?).returns(true)
    Adapters::Http::PublicDns.expects(:resolve).with("example.com").returns("93.184.216.34")
    Adapters::Http::PublicDns.expects(:resolve).with("private.example.com").raises(Adapters::Http::Unresolvable)
    stub_request(:get, "https://example.com/feed").to_return(status: 302, headers: { "Location" => "https://private.example.com/private" })

    assert_raises(Adapters::Http::Unresolvable) { Adapters::Http.get("https://example.com/feed") }
    assert_not_requested :get, "https://private.example.com/private"
  end
end
