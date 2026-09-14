require "test_helper"

class DeliverAlertJobTest < ActiveJob::TestCase
  test "两个渠道一个成一个败：只记成功的，抛错重试，重试时不重发成功的" do
    with_alert_channels(ALERT_EMAIL_TO: "drew@example.com", SMTP_ADDRESS: "smtp.example.com", ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      event = alert_event
      stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 500, body: "boom")

      assert_enqueued_with(job: DeliverAlertJob, args: [ event, "alert" ]) { DeliverAlertJob.perform_now(event, "alert") }
      event.reload
      assert_equal [ "email:alert" ], event.delivered
      assert_not_nil event.sent_at
      assert_equal "webhook 500: boom", event.delivery_error
      assert_equal 1, event.attempts
      assert_equal 1, ActionMailer::Base.deliveries.size

      stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 200, body: "ok")
      assert_no_difference("ActionMailer::Base.deliveries.size") { DeliverAlertJob.perform_now(event, "alert") }
      assert_equal [ "email:alert", "webhook:alert" ], event.reload.delivered
      assert_nil event.delivery_error
    end
  end

  test "恢复阶段单独记账" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      event = alert_event(delivered: [ "webhook:alert" ], sent_at: 1.hour.ago, recovered_at: Time.current)
      stub = stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 200)
      DeliverAlertJob.perform_now(event, "recovery")
      assert_requested stub, times: 1
      assert_equal [ "webhook:alert", "webhook:recovery" ], event.reload.delivered
      assert_not_nil event.recovery_sent_at
    end
  end

  test "三次都发不出去：耗尽后写一行日志并抛出，事件留着原因" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      event = alert_event
      stub_request(:post, AlertTestHelpers::WEBHOOK).to_timeout
      job = DeliverAlertJob.new(event, "alert")
      job.executions = 2
      # ActiveJob 自己也会用 error 级别记 job 失败，所以不数调用次数，直接抓我们那一行的文字
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      begin
        assert_raises(Alerts::DeliveryError) { job.perform_now }
      ensure
        Rails.logger = original
      end
      assert_includes io.string, "告警投递失败（alert，3 次）：AlertEvent##{event.id}"
      assert_match(/webhook/, event.reload.delivery_error)
      assert_nil event.sent_at
    end
  end

  # 恢复阶段的 job 会与告警阶段的重试撞在同一条事件上：两边都读改写 delivered，并发跑要丢更新
  test "同一条事件同时只允许一个投递任务" do
    assert_equal 1, DeliverAlertJob.concurrency_limit

    event = alert_event
    other = alert_event(dedup_key: "k2", source: sources(:github))
    key = DeliverAlertJob.new(event, "alert").concurrency_key
    assert_includes key, event.id
    assert_equal key, DeliverAlertJob.new(event, "recovery").concurrency_key
    refute_equal key, DeliverAlertJob.new(other, "alert").concurrency_key
  end

  test "两次重试分别等 30 秒与 120 秒" do
    with_alert_channels(ALERT_WEBHOOK_URL: AlertTestHelpers::WEBHOOK) do
      freeze_time do
        event = alert_event
        stub_request(:post, AlertTestHelpers::WEBHOOK).to_return(status: 502)
        assert_enqueued_with(job: DeliverAlertJob, at: 30.seconds.from_now) { DeliverAlertJob.perform_now(event, "alert") }
        second = ActiveJob::Base.deserialize(enqueued_jobs.last)
        clear_enqueued_jobs
        assert_enqueued_with(job: DeliverAlertJob, at: 120.seconds.from_now) { second.perform_now }
      end
    end
  end
end
