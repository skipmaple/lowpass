module Adapters
  class Base
    FETCH_TIMEOUT = 60
    TEST_TIMEOUT = 30

    attr_reader :source

    # 子类能回填历史日期的才改成 true（Issue.backfill_daily! 据此决定入队还是直接标无法回填）
    def self.backfill?
      false
    end

    def initialize(source)
      @source = source
    end

    def fetch(period_key: nil)
      Timeout.timeout(FETCH_TIMEOUT) { entries(period_key: period_key) }
    end

    # R-3.3 测试抓取：30 秒超时，返回全部条目；预览取前 5 条、数总数与丢弃数是 Source::TestFetch 的事
    def test_fetch
      Timeout.timeout(TEST_TIMEOUT) { entries(period_key: nil) }
    end

    # R-1.6 补生成：抓某个过去的上海日（Date）
    def backfill(date)
      Timeout.timeout(FETCH_TIMEOUT) { backfill_entries(date) }
    end

    private
      # 子类实现，返回 Array<Entry>
      def entries(period_key:)
        raise NotImplementedError
      end

      def backfill_entries(_date)
        raise NoBackfill, "该来源无法回填"
      end

      def config
        source.config.with_indifferent_access
      end

      def http(url, **options)
        Http.get(url, **options)
      end
  end
end
