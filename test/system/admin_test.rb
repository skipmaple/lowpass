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

    within(:xpath, "//*[@role='row'][.//*[contains(text(), '命令行周报')]]") { click_on "停用" }
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
      click_on "Hacker News"
      click_on "重抓"
    end

    assert_text "正在重抓 Hacker News…"
    perform_enqueued_jobs
    visit admin_issues_path(month: "2026-09")
    assert_text "已发布 · 已修订"
    assert_text "已更新 Hacker News（1 条）"
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
end
