require "test_helper"

class Reasons::ProgressTest < ActiveSupport::TestCase
  Job = Struct.new(:created_at, :finished_at, :claimed, :failed, keyword_init: true) do
    def finished? = finished_at.present?
    def claimed? = claimed
    def failed? = failed
    def arguments = { "arguments" => [ {}, false ] }
  end

  test "排队与执行中明确显示且不会把重试次数当更新条数" do
    issue = issues(:daily_0908)
    job = Job.new(created_at: 1.minute.ago, claimed: false, failed: false)
    progress = Reasons::Progress.new(issue, job).to_h
    assert_equal "queued", progress[:status]
    assert progress[:active]

    job.claimed = true
    2.times { ModelCall.create!(issue: issue, item: items(:hn_one), status: "invalid", error_summary: "不是 JSON", duration_ms: 10) }
    ModelCall.create!(issue: issue, item: items(:hn_one), status: "ok", duration_ms: 10)
    items(:hn_one).update!(reason: "已成功写回的测试理由", reason_generated_at: Time.current)
    progress = Reasons::Progress.new(issue, job).to_h
    assert_equal "running", progress[:status]
    assert_includes progress[:detail], "已更新 1 条"
    assert_nil progress[:error]
  end

  test "队列完成但理由没成功，不能显示已完成；旧理由也不能冒充本次成功" do
    issue = issues(:daily_0908)
    items(:hn_one).update!(reason: "旧理由仍保留", reason_generated_at: 2.days.ago)
    job = Job.new(created_at: 1.minute.ago, finished_at: Time.current, claimed: false, failed: false)
    ModelCall.create!(issue: issue, item: items(:hn_one), status: "invalid", error_summary: "条目资料不足，未生成理由", duration_ms: 10)
    job.finished_at = Time.current

    progress = Reasons::Progress.new(issue, job).to_h
    assert_equal "failed", progress[:status]
    assert_not progress[:active]
    assert_equal "条目资料不足，未生成理由", progress[:error]
  end

  test "部分更新显示实际缺失条数，完全更新后显示完成" do
    issue = issues(:daily_0908)
    second = issue.items.create!(source: sources(:hn), rank: 2, title: "second", url: "https://example.com/second", url_hash: Digest::SHA256.hexdigest("https://example.com/second"), fetched_at: Time.current)
    job = Job.new(created_at: 1.minute.ago, finished_at: Time.current, claimed: false, failed: false)
    items(:hn_one).update!(reason: "新理由", reason_generated_at: Time.current)
    ModelCall.create!(issue: issue, item: second, status: "timed_out", error_summary: "连接超时", duration_ms: 10)
    job.finished_at = Time.current

    progress = Reasons::Progress.new(issue, job).to_h
    assert_equal "partial", progress[:status]
    assert_includes progress[:detail], "仍缺 1 条"
    assert_equal "连接超时", progress[:error]

    second.update!(reason: "第二条也成功", reason_generated_at: Time.current)
    job.finished_at = Time.current
    progress = Reasons::Progress.new(issue, job).to_h
    assert_equal "completed", progress[:status]
    assert_nil progress[:error]
  end

  test "worker 异常中止明确失败且不暴露底层堆栈" do
    job = Job.new(created_at: 1.minute.ago, claimed: false, failed: true)
    progress = Reasons::Progress.new(issues(:daily_0908), job).to_h
    assert_equal "failed", progress[:status]
    assert_match(/任务中断/, progress[:error])
  end

  test "非持久队列适配器不读取队列数据库" do
    SolidQueue::Job.expects(:where).never
    assert_empty Reasons::Progress.for_issues([ issues(:daily_0908) ])
    assert_not Reasons::Progress.active?(issues(:daily_0908))
  end
end
