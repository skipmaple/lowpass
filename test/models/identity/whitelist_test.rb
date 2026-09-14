require "test_helper"

class Identity::WhitelistTest < ActiveSupport::TestCase
  # 直接改环境变量再还原（同一进程里的测试串行跑，并行 worker 各有自己的进程），不 stub ENV：ENV.fetch 别处也在用
  def with_whitelist(value)
    previous = ENV["ADMIN_EMAILS"]
    ENV["ADMIN_EMAILS"] = value
    yield
  ensure
    ENV["ADMIN_EMAILS"] = previous
  end

  test "逗号分隔、忽略空白与大小写、跳过空项" do
    with_whitelist(" A@x.io, ,b@y.io ") do
      assert_equal [ "a@x.io", "b@y.io" ], Identity::Whitelist.emails
      assert Identity::Whitelist.include_any?([ nil, "B@Y.IO " ])
      assert_not Identity::Whitelist.include_any?([ "c@z.io" ])
    end
  end

  test "没配就没人是 admin" do
    with_whitelist(nil) do
      assert_equal [], Identity::Whitelist.emails
      assert_not Identity::Whitelist.include_any?([ "drew@example.com" ])
    end
  end
end
