require "test_helper"

class Admin::JobsContextTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:drew))
    @adapter = adapter = ActiveJob::QueueAdapters::SolidQueueAdapter.new
    adapter.extend(ActiveJob::QueueAdapters::SolidQueueExt)
    adapter.stubs(:queues).returns([])
    adapter.stubs(:jobs_count).returns(0)
    adapter.stubs(:fetch_jobs).returns([])
    adapter.stubs(:count_workers).returns(0)
    adapter.stubs(:fetch_workers).returns([])
    adapter.stubs(:recurring_tasks).returns([])
    applications = MissionControl::Jobs::Applications.new
    applications.add("Lowpass", solid_queue: adapter)
    MissionControl::Jobs.stubs(:applications).returns(applications)
  end

  test "queue views retain admin context and empty workers have no impossible pager" do
    %w[ queues failed/jobs in_progress/jobs blocked/jobs scheduled/jobs finished/jobs workers recurring_tasks ].each do |view|
      get "/admin/jobs/applications/lowpass/#{view}", params: { server_id: "solid_queue" }
      assert_response :success
      assert_select "main", count: 1
      assert_select "h1", count: 1
      assert_select "a", text: "返回刊物管理" do |links|
        assert_equal "/admin/issues", links.first["href"]
      end
      assert_select "p", text: /时区：#{Regexp.escape(Time.zone.name)}/
      assert_select "p", text: /并发限制/ if view == "blocked/jobs"
      if view == "workers"
        assert_select "p", text: /没有正在运行的 Worker/
        assert_no_match %r{1\s*/\s*0}, response.body
      end
    end
  end
  test "scheduled and blocked actions confirm the exact job and retain POST forms" do
    job = ActiveJob::JobProxy.new(GenerateReasonsJob.new(issues(:daily_0908), false).serialize)
    job.enqueued_at = Time.current
    job.scheduled_at = 1.hour.from_now
    @adapter.stubs(:queues).returns([ { name: job.queue_name, size: 1, active: true } ])
    @adapter.stubs(:jobs_count).returns(1)
    @adapter.stubs(:fetch_jobs).returns([ job ])
    %w[ scheduled blocked ].each do |status|
      job.status = status.to_sym
      get "/admin/jobs/applications/lowpass/#{status}/jobs", params: { server_id: "solid_queue" }
      assert_response :success
      assert_select "form[method='post'][data-turbo-confirm]" do |forms|
        confirms = forms.map { |form| form["data-turbo-confirm"] }
        assert confirms.any? { |text| text.include?("Run GenerateReasonsJob (#{job.job_id}) now?") }
        assert confirms.all? { |text| text.include?(job.job_id) }
        if status == "scheduled"
          assert confirms.any? { |text| text.include?("without running it") }
        else
          assert confirms.any? { |text| text.include?("bypasses concurrency limits") }
        end
      end
    end
  end

  test "first and last queue pages expose named navigation without activatable disabled links" do
    job = ActiveJob::JobProxy.new(GenerateReasonsJob.new(issues(:daily_0908), false).serialize)
    job.enqueued_at = Time.current
    job.status = :finished
    job.finished_at = Time.current
    @adapter.stubs(:queues).returns([ { name: job.queue_name, size: 11, active: true } ])
    @adapter.stubs(:jobs_count).returns(11)
    @adapter.stubs(:fetch_jobs).returns([ job ])

    get "/admin/jobs/applications/lowpass/finished/jobs", params: { server_id: "solid_queue", page: 1 }
    assert_response :success
    assert_select "a[aria-current='page']", text: /Finished jobs/
    assert_select "nav[aria-label='pagination']" do
      assert_select "span[aria-disabled='true'][aria-label='First page']"
      assert_select "span[aria-disabled='true'][aria-label='Previous page']"
      assert_select "[aria-disabled='true'][href]", count: 0
      assert_select "a[aria-label='Last page']"
      assert_select "[aria-current='page']", text: "1"
    end

    get "/admin/jobs/applications/lowpass/finished/jobs", params: { server_id: "solid_queue", page: 2 }
    assert_response :success
    assert_select "nav[aria-label='pagination']" do
      assert_select "a[aria-label='First page']"
      assert_select "span[aria-disabled='true'][aria-label='Next page']"
      assert_select "span[aria-disabled='true'][aria-label='Last page']"
      assert_select "[aria-disabled='true'][href]", count: 0
      assert_select "[aria-current='page']", text: "2"
    end
  end
end
