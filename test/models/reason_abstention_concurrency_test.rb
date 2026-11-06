require "test_helper"
require "timeout"

class ReasonAbstentionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @issue = Issue.create!(kind: "daily", period_key: "2090-01-01", state: "published", published_at: Time.current, generation_started_at: Time.current)
    @item = @issue.items.create!(source: sources(:hn), title: "Concurrency test", url: "https://example.test/locked", url_hash: Digest::SHA256.hexdigest("locked"), fetched_at: Time.current)
  end

  teardown { @issue&.destroy! }

  test "并发拒写受条目锁保护且只有一条判断" do
    ready, start = Queue.new, Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          item = Item.find(@item.id)
          item.reason_abstention
          ready << true
          start.pop
          item.record_reason_abstention(assessed_at: Time.current)
        end
      end
    end
    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { start << true }
    threads.each(&:value)
    assert_equal 1, ReasonAbstention.where(item_id: @item.id).count
    assert_nil @item.reload.reason
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  [ :generated, :abstained ].each do |last|
    test "并发最后合法提交为 #{last} 时内容与判断一致" do
      held, release, competing = Queue.new, Queue.new, Queue.new
      first = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          item = Item.find(@item.id)
          item.with_lock do
            apply(item, last == :generated ? :abstained : :generated)
            held << true
            release.pop
          end
        end
      end
      Timeout.timeout(5) { held.pop }
      second = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          item = Item.find(@item.id)
          item.reason_abstention
          competing << true
          apply(item, last)
        end
      end
      Timeout.timeout(5) { competing.pop }
      release << true
      [ first, second ].each(&:value)
      assert_equal last == :abstained ? 1 : 0, ReasonAbstention.where(item_id: @item.id).count
      assert_equal "前端开发可考察这个终端工具的调试流程与使用边界。", @item.reload.reason
    ensure
      [ first, second ].compact.each { |thread| thread.kill if thread.alive? }
    end
  end

  private
    def apply(item, decision)
      if decision == :abstained
        item.record_reason_abstention(assessed_at: Time.current)
      else
        result = Reasons::Parser::Result.new(decision: "generated", reason: "前端开发可考察这个终端工具的调试流程与使用边界。", interest_tag: "前端开发", title_zh: nil, summary_zh: nil)
        item.store_generated_reason(result, generated_at: Time.current)
      end
    end
end
