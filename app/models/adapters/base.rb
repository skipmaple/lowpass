module Adapters
  class Base
    FETCH_TIMEOUT = 60
    TEST_TIMEOUT = 30

    attr_reader :source

    def initialize(source)
      @source = source
    end

    def fetch(period_key: nil)
      Timeout.timeout(FETCH_TIMEOUT) { entries(period_key: period_key) }
    end

    def test_fetch
      Timeout.timeout(TEST_TIMEOUT) { entries(period_key: nil).first(5) }
    end

    private
      # 子类实现，返回 Array<Entry>
      def entries(period_key:)
        raise NotImplementedError
      end

      def config
        source.config.with_indifferent_access
      end

      def http(url, **options)
        Http.get(url, **options)
      end
  end
end
