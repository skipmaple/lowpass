ENV["RAILS_ENV"] ||= "test"
# R-5.5 的白名单从环境读；测试不依赖机器上的环境变量，fixture 里 drew 就是这个人
ENV["ADMIN_EMAILS"] = "drew@example.com"
require_relative "../config/environment"
require "rails/test_help"

require "webmock/minitest"
require "mocha/minitest"

Dir[Rails.root.join("test/test_helpers/**/*.rb")].sort.each { |file| require file }
WebMock.disable_net_connect!(allow_localhost: true)

# 登录走 OmniAuth 的 mock（test/test_helpers/authentication_test_helpers.rb），不连 Google / GitHub
OmniAuth.config.test_mode = true

module FixtureUuids
  extend ActiveSupport::Concern
  class_methods do
    def identify(label, column_type = :integer)
      return super unless column_type.in?([ :uuid, :string ])
      Lowpass::Uuid.for_fixture(label)
    end
  end
end
ActiveSupport.on_load(:active_record_fixture_set) { prepend FixtureUuids }

class ActiveSupport::TestCase
  # 核数很高的机器上一次性开满 worker 会把 PostgreSQL 连接池压出间歇性失败，封顶 8 个；
  # ENV["PARALLEL_WORKERS"] 仍然优先生效（parallelize 内部先看这个环境变量）。用
  # Concurrent.available_processor_count（cgroup 配额感知，容器里跑测试时不会数到宿主机的全部核数）
  # 兜底到 Concurrent.processor_count，和 Rails 自己 workers: :number_of_processors 的默认实现一致
  # （activesupport 的 ActiveSupport::TestCase.parallelize 内部正是这一行）；配额可能是分数（比如
  # 2.5 个核），先 floor 成整数再取 min，避免把非整数传给 workers。
  parallelize(workers: [ (Concurrent.available_processor_count || Concurrent.processor_count).floor, 8 ].min)
  fixtures :all
  include ActiveJob::TestHelper
  include SearchTestHelpers
  include AuthenticationTestHelpers
  include AlertTestHelpers
end

class ActionDispatch::IntegrationTest
  # rate_limit 与回调限流的计数都在 memory_store 里；上一条测试的登录次数不能漏进这一条
  setup { Rails.cache.clear }

  # OmniAuth.config.mock_auth 是进程级的：不清掉，忘了 mock_omniauth 的测试会拿上一条测试的身份登录成功
  teardown { OmniAuth.config.mock_auth.clear }

  # inertia_rails 的 use_script_element_for_initial_page 把整个 payload 渲染成
  # <script data-page="app" type="application/json"> 的文本内容（page.to_json.html_safe，没有 HTML 转义），
  # 没有开 SSR，所以页面上能读到的每个字符串都必须先出现在 props 里。
  def page
    JSON.parse(response.body[%r{<script data-page="app"[^>]*>(.*?)</script>}m, 1])
  end

  def page_props = page.fetch("props")
  def page_component = page.fetch("component")
end
