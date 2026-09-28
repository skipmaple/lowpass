require "test_helper"

class HealthTest < ActiveSupport::TestCase
  def sh(str) = Time.find_zone("Asia/Shanghai").parse(str)

  # 一切正常的底子：刚 tick 过，当天的期已发布
  def healthy_at(now)
    Setting.set("ticked_at", (now - 1.minute).iso8601)
    Issue.daily.create!(period_key: PeriodKey.daily(now), state: "published", generation_started_at: now.change(hour: 6), published_at: now.change(hour: 6, min: 12))
  end

  test "五项都好：ok；备份在不需要的环境里跳过" do
    now = sh("2026-09-28 10:00")
    healthy_at(now)
    report = Health.check(now: now)

    assert report.ok?
    assert_equal({ database: "ok", search: "ok", scheduler: "ok", daily_issue: "ok", backup: "skipped" }, report.checks)
    json = report.as_json
    assert_equal "ok", json["status"]
    assert_equal "2026-09-28T10:00:00+08:00", json["checked_at"]
    assert_equal({ "latest" => "2026-09-28", "expected" => "2026-09-28", "published_at" => "2026-09-28T06:12:00+08:00", "age_minutes" => 228 }, json["daily_issue"])
    assert_equal "2026-09-28T09:59:00+08:00", json.dig("scheduler", "ticked_at")
    assert json["search"].key?("latency_ms")
  end

  test "调度：心跳超过 5 分钟就是停了" do
    now = sh("2026-09-28 10:00")
    healthy_at(now)
    Setting.set("ticked_at", (now - 5.minutes).iso8601)
    assert_equal "ok", Health.check(now: now).checks[:scheduler]

    Setting.set("ticked_at", (now - 5.minutes - 1.second).iso8601)
    report = Health.check(now: now)
    assert_equal "fail", report.checks[:scheduler]
    assert_not report.ok?
  end

  test "调度：从来没 tick 过也是停了" do
    assert_equal "fail", Health.check(now: sh("2026-09-28 10:00")).checks[:scheduler]
  end

  # 生成时间 06:00，「日刊未生成」以 06:30 为界（设计 B4）：此前昨日期在就行
  test "日刊：06:30 之前看昨日期，之后必须有当日期" do
    Issue.daily.create!(period_key: "2026-09-27", state: "published", generation_started_at: sh("2026-09-27 06:00"), published_at: sh("2026-09-27 06:10"))

    assert_equal "ok", Health.check(now: sh("2026-09-28 06:29:59")).checks[:daily_issue]
    report = Health.check(now: sh("2026-09-28 06:30"))
    assert_equal "fail", report.checks[:daily_issue]
    assert_equal "2026-09-28", report.as_json.dig("daily_issue", "expected")
  end

  test "日刊：生成时间改了，界线跟着改" do
    Setting.set("daily_time", "07:15")
    Issue.daily.create!(period_key: "2026-09-27", state: "published", generation_started_at: sh("2026-09-27 07:15"))
    assert_equal "ok", Health.check(now: sh("2026-09-28 07:44")).checks[:daily_issue]
    assert_equal "fail", Health.check(now: sh("2026-09-28 07:45")).checks[:daily_issue]
  end

  # 空刊、生成中都算「期在」：内容层面的事故由告警管（issue_empty），不是这个端点的事
  test "日刊：当日期在就行，不看状态" do
    Issue.daily.create!(period_key: "2026-09-28", state: "empty", generation_started_at: sh("2026-09-28 06:00"))
    assert_equal "ok", Health.check(now: sh("2026-09-28 10:00")).checks[:daily_issue]
  end

  test "备份：需要备份时，最近一次成功不超过 50 小时" do
    now = sh("2026-09-28 10:00")
    healthy_at(now)
    with_backup_config do
      assert_equal "ok", Health.check(now: now).checks[:backup], "一条记录都没有：刚部署，不判"

      BackupRun.create!(trigger: "scheduled", status: "succeeded", created_at: now - 49.hours, finished_at: now - 49.hours)
      assert_equal "ok", Health.check(now: now).checks[:backup]

      BackupRun.update_all(finished_at: now - 51.hours)
      report = Health.check(now: now)
      assert_equal "fail", report.checks[:backup]
      assert_equal (now - 51.hours).iso8601, report.as_json.dig("backup", "last_succeeded_at")
    end
  end

  test "备份：一次都没成功过，从第一条记录起算" do
    now = sh("2026-09-28 10:00")
    with_backup_config do
      BackupRun.create!(trigger: "scheduled", status: "failed", created_at: now - 2.hours)
      assert_equal "ok", Health.check(now: now).checks[:backup]

      BackupRun.update_all(created_at: now - 51.hours)
      assert_equal "fail", Health.check(now: now).checks[:backup]
    end
  end

  test "搜索探测超时就是 fail；不计入 B5 的连续失败计数" do
    now = sh("2026-09-28 10:00")
    healthy_at(now)
    Search::Runner.stubs(:probe).returns(Search::Result.new(entries: [], total: 0, page: 1, latency_ms: 1000, status: "timeout"))
    Alerts.expects(:search_status).never

    report = Health.check(now: now)
    assert_equal "fail", report.checks[:search]
    assert_equal 1000, report.as_json.dig("search", "latency_ms")
  end

  test "一项出错：记成 fail 并报告，别的照查，返回里没有异常信息" do
    now = sh("2026-09-28 10:00")
    healthy_at(now)
    Search::Runner.stubs(:probe).raises(PG::ConnectionBad, "could not connect to server db.internal:5432")

    report = nil
    assert_error_reported(PG::ConnectionBad) { report = Health.check(now: now) }
    assert_equal "fail", report.checks[:search]
    assert_equal "ok", report.checks[:daily_issue]
    assert_not_includes report.as_json.to_json, "db.internal"
  end
end
