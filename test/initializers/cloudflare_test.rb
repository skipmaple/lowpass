require "test_helper"

# config/initializers/cloudflare.rb 的挂载位置。按真实访客计数的效果由 sessions_controller_test 的 R-5.9 几条盯着
class CloudflareTest < ActiveSupport::TestCase
  test "排在登录回调限流之前" do
    names = Rails.application.config.middleware.map(&:name)

    assert_operator names.index("Cloudflare::ClientIp"), :<, names.index("Auth::CallbackRateLimit")
  end
end
