require "test_helper"

class Alerts::ChannelsTest < ActiveSupport::TestCase
  test "配了哪个就发哪个" do
    assert_equal [], Alerts::Channels.configured
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) { assert_equal [ Alerts::Channels::Webhook ], Alerts::Channels.configured }
    with_alert_channels(ALERT_EMAIL_TO: "drew@example.com", SMTP_ADDRESS: "smtp.example.com", ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      assert_equal [ Alerts::Channels::Email, Alerts::Channels::Webhook ], Alerts::Channels.configured
    end
  end

  test "webhook 四种报文形状" do
    event = alert_event
    text = nil
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK, BASE_URL: "https://lowpass.example.com") { text = Alerts::Message.text(event, "alert") }
    {
      "generic" => { "text" => text, "title" => "[lowpass] 警告 · 源抓取失败 · Hacker News", "level" => "warning", "kind" => "source_failed",
                     "url" => "https://lowpass.example.com/admin/sources/#{sources(:hn).id}/runs" },
      "feishu" => { "msg_type" => "text", "content" => { "text" => text } },
      "wecom" => { "msgtype" => "text", "text" => { "content" => text } },
      "dingtalk" => { "msgtype" => "text", "text" => { "content" => text } }
    }.each do |format, body|
      with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK, ALERT_WEBHOOK_FORMAT: format, BASE_URL: "https://lowpass.example.com") do
        # wecom 与 dingtalk 报文字节相同：WebMock 的请求台账是全测试方法累计的（reset! 只在 teardown 跑一次），
        # 不清零的话跑到 dingtalk 时台账里已经有一条 wecom 发出的同款请求，assert_requested 的默认「恰好一次」会数成两次
        WebMock.reset!
        stub = stub_request(:post, AlertTestHelpers::WEBHOOK)
                 .with(headers: { "Content-Type" => "application/json", "User-Agent" => Adapters::Http::USER_AGENT }) { |request| JSON.parse(request.body) == body }
                 .to_return(status: 200, body: "ok")
        Alerts::Channels::Webhook.deliver(event, "alert")
        assert_requested stub
      end
    end
  end

  test "webhook 非 2xx 与超时都抛 DeliveryError，带状态码" do
    event = alert_event
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 500, body: "boom")
      error = assert_raises(Alerts::DeliveryError) { Alerts::Channels::Webhook.deliver(event, "alert") }
      assert_equal "webhook 500: boom", error.message

      # 消息要整体封顶 200 字（AlertEvent#delivery_error 的列上限与 CHECK），不能只截 body 那一段——
      # 否则"webhook 500: " 前缀一加，body 截到 200 后总长还是会超
      stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 500, body: "x" * 300)
      error = assert_raises(Alerts::DeliveryError) { Alerts::Channels::Webhook.deliver(event, "alert") }
      assert_operator error.message.length, :<=, 200
      assert error.message.start_with?("webhook 500: ")

      stub_request(:post, AlertTestHelpers::WEBHOOK).to_timeout
      assert_raises(Alerts::DeliveryError) { Alerts::Channels::Webhook.deliver(event, "alert") }
    end
  end

  # Net::HTTP 的响应体标成 ASCII-8BIT：直接按字节截再拼进中文消息会抛 Encoding::CompatibilityError，
  # 逃出 DeliveryError 体系，DeliverAlertJob 的 rescue 就接不住了（与 Reasons::Provider 同一处问题）
  test "webhook 响应体是带非法字节的二进制串：仍然是 DeliveryError" do
    event = alert_event
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 500, body: "网关错误 ".b + "\xE7".b)
      error = assert_raises(Alerts::DeliveryError) { Alerts::Channels::Webhook.deliver(event, "alert") }
      assert error.message.start_with?("webhook 500:"), error.message
      assert_equal Encoding::UTF_8, error.message.encoding
      assert error.message.valid_encoding?
    end
  end

  test "邮件渠道发给全部收件人，SMTP 出错换成 DeliveryError" do
    event = alert_event
    with_alert_channels(ALERT_EMAIL_TO: "drew@example.com, ops@example.com", SMTP_ADDRESS: "smtp.example.com", BASE_URL: "https://lowpass.example.com") do
      assert_difference("ActionMailer::Base.deliveries.size", 1) { Alerts::Channels::Email.deliver(event, "alert") }
      assert_equal [ "drew@example.com", "ops@example.com" ], ActionMailer::Base.deliveries.last.to

      AlertMailer.any_instance.stubs(:mail).raises(Net::SMTPFatalError, "550")
      error = assert_raises(Alerts::DeliveryError) { Alerts::Channels::Email.deliver(event, "alert") }
      assert_match(/email Net::SMTPFatalError: 550/, error.message)
    end
  end
end
