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
