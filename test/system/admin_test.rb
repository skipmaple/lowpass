require "application_system_test_case"

# P2-② 出口：3 分钟内新建一个 RSS 源（AC-3.1 / AC-3.2 的前半）、停用它、看抓取记录；对某期某源重抓看到「已修订」
class AdminTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
    Surfguard.stubs(:resolve_public_ips).returns([ "1.1.1.1" ])
    stub_request(:get, "https://w.example/feed").to_return(body: file_fixture("rss/atom_sample.xml").read)
  end

  test "新建 RSS 源：测试抓取看到预览，保存后出现在列表，停用要确认" do
    visit admin_sources_path
    click_on "新建来源"

    fill_in "feed 地址", with: "https://w.example/feed"
    # 「周刊」在「刊物」分段里，与适配器分段的「阮一峰周刊」重名一段；不圈定分组会撞成 Ambiguous
    within("[aria-label='刊物']") { click_on "周刊" }
    click_on "测试抓取"
    assert_text "测试抓取 · 前 5 条"
    assert_field "名称", with: "Example Atom Feed"
    fill_in "名称", with: "命令行周报"
    click_on "保存"

    assert_current_path admin_sources_path
    assert_text "已保存 命令行周报"
    assert_text "命令行周报"

    within(:xpath, "//*[@role='row'][.//*[contains(text(), '命令行周报')]]") do
      find("summary", text: "更多操作").click
      click_on "停用"
    end
    assert_text "停用后不再抓取，历史内容保留。确认停用 命令行周报？"
    within("[role='dialog']") { click_on "停用" }
    assert_text "已停用 命令行周报"
    assert_not Source.find_by!(name: "命令行周报").enabled
  end

  test "对某期某源重抓：进行中、结束后已修订" do
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "重抓来的", url: "https://h/re") ])

    visit admin_issues_path(month: "2026-09")
    within(:xpath, "//*[@role='row'][.//*[text()='2026-09-08']]") { click_on "重抓某源" }
    within("[role='dialog']") do
      choose "Hacker News"
      click_on "重抓 Hacker News"
    end

    assert_text "正在重抓 Hacker News…"
    perform_enqueued_jobs
    visit admin_issues_path(month: "2026-09")
    assert_text "已发布 · 已修订"
    assert_text "2026-09-08 · 已更新 Hacker News（1 条）"
  end

  test "队列分页四个目标至少 44 像素，禁用项不可激活且首尾有名称" do
    adapter = ActiveJob::QueueAdapters::SolidQueueAdapter.new
    adapter.extend(ActiveJob::QueueAdapters::SolidQueueExt)
    job = ActiveJob::JobProxy.new(GenerateReasonsJob.new(issues(:daily_0908), false).serialize)
    job.status = :scheduled
    job.enqueued_at = Time.current
    job.scheduled_at = 1.hour.from_now
    adapter.stubs(:queues).returns([ { name: job.queue_name, size: 1, active: true } ])
    adapter.stubs(:jobs_count).returns(1)
    adapter.stubs(:fetch_jobs).returns([ job ])
    applications = MissionControl::Jobs::Applications.new
    applications.add("Lowpass", solid_queue: adapter)
    MissionControl::Jobs.stubs(:applications).returns(applications)

    labels = [ "First page", "Previous page", "Next page", "Last page" ]
    assert_pagination = ->(disabled_labels) do
      within "nav[aria-label='pagination']" do
        assert_selector ".pagination-previous, .pagination-next", count: 4
        labels.each do |label|
          target = find("[aria-label='#{label}']")
          assert_operator target.native.rect.width, :>=, 44
          assert_operator target.native.rect.height, :>=, 44
          if disabled_labels.include?(label)
            assert_equal "span", target.tag_name
            assert_equal "true", target["aria-disabled"]
            assert_nil target["href"]
            assert_nil target["tabindex"]
            original_url = page.current_url
            target.click
            assert_equal original_url, page.current_url
          else
            assert_equal "a", target.tag_name
            assert target["href"].present?
            assert_nil target["aria-disabled"]
          end
        end
      end
    end

    visit "/admin/jobs/applications/lowpass/scheduled/jobs?server_id=solid_queue"
    assert_selector "h1", text: "Scheduled jobs"
    assert_pagination.call(labels)

    adapter.stubs(:jobs_count).returns(11)
    visit "/admin/jobs/applications/lowpass/scheduled/jobs?server_id=solid_queue&page=1"
    assert_pagination.call([ "First page", "Previous page" ])
    assert_selector "nav[aria-label='pagination'] [aria-current='page']", text: "1", exact_text: true

    visit "/admin/jobs/applications/lowpass/scheduled/jobs?server_id=solid_queue&page=2"
    assert_pagination.call([ "Next page", "Last page" ])
    assert_selector "nav[aria-label='pagination'] [aria-current='page']", text: "2", exact_text: true
  end

  test "成员看不到后台" do
    find("button[aria-label='账户']").click
    click_on "登出"
    sign_in_with_browser(users(:guest))

    visit admin_sources_path

    assert_text "你没有权限访问这个页面。"
  end

  test "AC-7.1 发送测试告警：webhook 收到一次，事件记下投递时间" do
    Alerts::Config.load!({ "ALERT_WEBHOOK_URL" => "https://hooks.example/lowpass", "BASE_URL" => "http://localhost:3000" })
    stub_request(:post, "https://hooks.example/lowpass").to_return(status: 200, body: "ok")

    visit admin_settings_path
    click_on "发送测试告警"
    assert_text "已发送测试告警"

    perform_enqueued_jobs
    assert_requested :post, "https://hooks.example/lowpass", times: 1
    assert_not_nil AlertEvent.find_by!(kind: "test").sent_at
  ensure
    Alerts::Config.load!({})
  end

  test "AC-9.1 / AC-9.4 配置供应商后整期重生成，读者页看到理由与标签" do
    Setting.set("model_base_url", "https://model.example/v1")
    Setting.set("model_name", "test-model")
    Reasons::Provider.stubs(:api_key).returns("test-key")
    stub_request(:post, "https://model.example/v1/chat/completions").to_return(status: 200, body: model_reply(reason: "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。", interest_tag: "AI / LLM"))

    visit admin_issues_path(month: "2026-09")
    within(:xpath, "//*[@role='row'][.//*[text()='2026-09-08']]") { click_on "重生成理由" }
    assert_text "2026-09-08 · 已开始重生成理由"
    perform_enqueued_jobs

    visit daily_issue_path("2026-09-08")
    assert_text "用 Rust 写的终端日志工具，对开发者效率有帮助，值得一看。"
    assert_text "AI / LLM"
  ensure
    Setting.set("model_base_url", "")
    Setting.set("model_name", "")
  end
end
