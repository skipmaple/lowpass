require "test_helper"

class GenerateReasonsJobTest < ActiveJob::TestCase
  test "一期一个" do
    assert_equal 1, GenerateReasonsJob.concurrency_limit
    # concurrency_key 是 "GenerateReasonsJob/<id>"（solid_queue 按类名分组），跟
    # test/jobs/fetch_source_job_test.rb 的断言方式一样只认里面带没带这一期的 id
    assert_includes GenerateReasonsJob.new(issues(:daily_0908)).concurrency_key, issues(:daily_0908).id
  end

  test "调生成器，默认只补空的" do
    Reasons::Generator.expects(:generate!).with(issues(:daily_0908), only_missing: true)
    GenerateReasonsJob.perform_now(issues(:daily_0908))
    Reasons::Generator.expects(:generate!).with(issues(:daily_0908), only_missing: false)
    GenerateReasonsJob.perform_now(issues(:daily_0908), false)
  end
end
