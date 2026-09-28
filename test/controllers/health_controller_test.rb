require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  setup { HealthController::RATE_LIMIT_STORE.clear }

  # 给外部拨测：不登录也能看，看到的只有状态
  test "不登录可访问：都好时 200" do
    travel_to Time.find_zone("Asia/Shanghai").parse("2026-09-28 10:00")
    Setting.set("ticked_at", 1.minute.ago.iso8601)
    Issue.daily.create!(period_key: "2026-09-28", state: "published", generation_started_at: 4.hours.ago, published_at: 4.hours.ago)

    get health_path

    assert_response :ok
    assert_equal "application/json", response.media_type
    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal %w[ database search scheduler daily_issue backup ], body["checks"].keys
  end

  test "任一项不好：503，JSON 里标出是哪一项" do
    get health_path

    assert_response :service_unavailable
    body = response.parsed_body
    assert_equal "fail", body["status"]
    assert_equal "fail", body.dig("checks", "scheduler")
    assert_equal "ok", body.dig("checks", "database")
  end

  test "按 IP 每分钟 30 次" do
    30.times { get health_path }
    get health_path
    assert_response :too_many_requests
  end
end
