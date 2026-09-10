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
  parallelize(workers: :number_of_processors)
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
