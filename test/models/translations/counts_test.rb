require "test_helper"

class Translations::CountsTest < ActiveSupport::TestCase
  test "真实待补与保留计数不依赖理由画像且批量查询" do
    item = items(:hn_one)
    item.record_reason_abstention(assessed_at: Time.current)
    with_model_provider do
      InterestArea.update_all(enabled: false)
      row = Issue.admin_rows(kind: "daily", month: "2026-09", now: Time.utc(2026, 9, 10))[:rows].find { |r| r[:period_key] == "2026-09-08" }
      assert_equal({ pending: 1, preserved: 0, ready: true, unready_label: nil }, row.fetch(:translations))
      item.store_translation(Translations::Parser::Result.new(decision: "unchanged", text: nil), target: item.translation_target, assessed_at: Time.current)
      assert_equal({ pending: 0, preserved: 1 }, Item.translation_counts_by_issue([ item.issue_id ]).fetch(item.issue_id))
      item.update!(title_zh: "已有译文")
      assert_equal({ pending: 0, preserved: 0 }, Item.translation_counts_by_issue([ item.issue_id ]).fetch(item.issue_id))
    end
    ids = [ item.issue_id ]
    20.times do |n|
      issue = Issue.create!(kind: "daily", period_key: format("2026-09-%02d", n + 9), state: "published", published_at: Time.current, generation_started_at: Time.current)
      ids << issue.id
      Item.create!(item.attributes.except("id", "issue_id").merge("issue" => issue, "title_zh" => nil))
    end
    queries = []
    listener = ->(*args) { queries << args.last[:sql] unless args.last[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") { Item.translation_counts_by_issue(ids) }
    assert_operator queries.size, :<=, 5
  end

  test "账本总数保留两目的且显示各自次数" do
    ModelCall.create!(status: "ok", cost: "0.1")
    ModelCall.create!(status: "invalid", purpose: "translation", operation_key: SecureRandom.uuid, input_field: "title", input_digest: "a" * 64, cost: "0.2")
    status = Reasons::Status.props
    assert_equal 2, status.fetch(:month_calls)
    assert_equal 1, status.fetch(:month_reason_calls)
    assert_equal 1, status.fetch(:month_translation_calls)
    assert_equal "0.3", status.fetch(:month_cost)
  end
end
