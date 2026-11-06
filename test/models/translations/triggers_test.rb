require "test_helper"

class Translations::TriggersTest < ActiveJob::TestCase
  test "当日发布冻结id，跨午夜执行沿用范围，历史发布不授权翻译" do
    issue = issues(:daily_0908)
    travel_to Time.new(2026, 9, 8, 23, 59, 0, "+08:00") do
      issue.update!(state: "generating", source_states: Source.enabled.daily.pluck(:id).index_with { "ok" })
      issue.finalize!(reason: "complete")
      args = ActiveJob::Arguments.deserialize(enqueued_jobs.last[:args])
      assert_equal [ items(:hn_one).id ], args.last.fetch("translation_targets").map { |t| t.fetch("item_id") }
      operation = args.last.fetch("operation")
      travel 2.minutes
        InterestArea.update_all(enabled: false)
        with_model_provider do
          stub = stub_request(:post, ReasonsTestHelpers::MODEL_ENDPOINT).to_return(status: 200, body: { choices: [ { message: { content: { decision: "translated", text: "午夜后仍属于原范围" }.to_json } } ] }.to_json)
          GenerateReasonsJob.perform_now(*args)
          assert_requested stub, times: 1
          assert_equal operation.fetch("key"), ModelCall.sole.operation_key
        end
    end
    clear_enqueued_jobs
    travel_to Time.new(2026, 9, 10, 6, 0, 0, "+08:00") do
      issue.update!(state: "generating")
      issue.finalize!(reason: "complete")
      assert_equal [], ActiveJob::Arguments.deserialize(enqueued_jobs.last[:args]).last.fetch("translation_targets")
    end
  end

  test "重抓只传本次实际写入id，历史重抓保持无翻译授权" do
    issue = issues(:daily_0908)
    other = Item.create!(items(:hn_one).attributes.except("id").merge("source_id" => sources(:hackaday).id))
    Adapters::HackerNews.any_instance.stubs(:fetch).returns([ Adapters::Entry.new(title: "New English story", url: "https://example.test/new", rank: 1) ])
    travel_to Time.new(2026, 9, 8, 20, 0, 0, "+08:00") do
      sources(:hn).fetch_now(issue, trigger: "manual")
      targets = ActiveJob::Arguments.deserialize(enqueued_jobs.last[:args]).last.fetch("translation_targets")
      assert_equal issue.items.where(source: sources(:hn)).pluck(:id), targets.map { |t| t.fetch("item_id") }
      assert_not_includes targets.map { |t| t.fetch("item_id") }, other.id
    end
    clear_enqueued_jobs
    travel_to Time.new(2026, 9, 9, 6, 0, 0, "+08:00") do
      sources(:hn).fetch_now(issue, trigger: "manual")
      assert_equal [], ActiveJob::Arguments.deserialize(enqueued_jobs.last[:args]).last.fetch("translation_targets")
    end
  end

  test "装订返回真实写入id和去重计数" do
    result = issues(:daily_0908).replace_section!(sources(:hn), [ Adapters::Entry.new(title: "A", url: "https://example.test/a"), Adapters::Entry.new(title: "A duplicate", url: "https://example.test/a") ])
    assert_equal 1, result.dropped_count
    assert_equal issues(:daily_0908).items.pluck(:id), result.written_ids
  end
end
