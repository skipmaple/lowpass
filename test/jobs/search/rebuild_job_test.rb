require "test_helper"

class Search::RebuildJobTest < ActiveJob::TestCase
  test "重建走 Search::Record.rebuild!" do
    Search::Record.expects(:rebuild!).once
    Search::RebuildJob.perform_now
  end
end
