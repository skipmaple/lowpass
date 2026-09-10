ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require "webmock/minitest"
require "mocha/minitest"
WebMock.disable_net_connect!(allow_localhost: true)

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
  # ENV["PARALLEL_WORKERS"] 仍然优先生效（parallelize 内部先看这个环境变量）。
  parallelize(workers: [ Concurrent.processor_count, 8 ].min)
  fixtures :all
  include ActiveJob::TestHelper
end

class ActionDispatch::IntegrationTest
  # inertia_rails 的 use_script_element_for_initial_page 把整个 payload 渲染成
  # <script data-page="app" type="application/json"> 的文本内容（page.to_json.html_safe，没有 HTML 转义），
  # 没有开 SSR，所以页面上能读到的每个字符串都必须先出现在 props 里。
  def page_props
    JSON.parse(response.body[%r{<script data-page="app"[^>]*>(.*?)</script>}m, 1]).fetch("props")
  end
end
