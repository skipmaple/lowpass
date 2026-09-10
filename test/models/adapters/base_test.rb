require "test_helper"

class Adapters::BaseTest < ActiveSupport::TestCase
  class Fake < Adapters::Base
    private
      def entries(period_key:)
        (1..7).map { |i| Adapters::Entry.new(title: "t#{i}", url: "https://a.b/#{i}", meta: { period_key: period_key }) }
      end
  end

  test "fetch 把周期键交给子类并返回全部条目" do
    entries = Fake.new(sources(:hn)).fetch(period_key: "2026-09-08")
    assert_equal 7, entries.size
    assert_equal "2026-09-08", entries.first.meta[:period_key]
  end

  test "test_fetch 只取前 5 条" do
    assert_equal 5, Fake.new(sources(:hn)).test_fetch.size
  end

  test "基类不实现 entries" do
    assert_raises(NotImplementedError) { Adapters::Base.new(sources(:hn)).fetch }
  end
end
