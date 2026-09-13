require "test_helper"

class Admin::Sources::RunsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "记录页：最近 50 条、筛选、最新一期与轮询数据" do
    sources(:hn).fetch_runs.create!(issue: issues(:daily_0908), trigger: "manual", attempt: 1, status: "running", started_at: Time.current)

    get admin_source_runs_path(sources(:hn), status: "failed")

    assert_equal "Admin/Sources/Runs", page_component
    assert_equal "Hacker News", page_props.dig("source", "name")
    assert_equal "failed", page_props["status"]
    assert page_props["runs"].all? { |r| r["status"].in?(%w[ failed timed_out ]) }
    assert_equal({ "period_key" => "2026-09-08", "label" => "9月8日" }, page_props["latest_issue"])
    assert_equal 1, page_props["active_runs"].size
    assert_equal [], page_props["finished_runs"]
  end

  test "非法筛选当全部" do
    get admin_source_runs_path(sources(:hn), status: "nope")

    assert_equal "all", page_props["status"]
    assert_equal 1, page_props["runs"].size
  end

  test "周刊源的最新一期是周刊" do
    get admin_source_runs_path(sources(:ruanyf))

    assert_equal({ "period_key" => "2026-W36", "label" => "第 36 周" }, page_props["latest_issue"])
  end

  test "成员是 403" do
    sign_in_as(users(:guest))
    get admin_source_runs_path(sources(:hn))
    assert_response :forbidden
  end
end
