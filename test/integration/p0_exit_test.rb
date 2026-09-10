require "test_helper"

class P0ExitTest < ActiveSupport::TestCase
  test "四个适配器都有基于样本的测试" do
    %w[ hacker_news github_trending rss ruanyf_weekly ].each do |a|
      assert File.exist?(Rails.root.join("test/models/adapters/#{a}_test.rb")), a
    end
    assert Dir[Rails.root.join("test/fixtures/files/ruanyf/issue-*.md")].size >= 20
  end

  test "缺期、延迟、空刊三条路径都有测试" do
    src = File.read(Rails.root.join("test/models/scheduler_test.rb")) + File.read(Rails.root.join("test/models/issue/daily_test.rb"))
    assert_includes src, "late: true"
    assert_includes src, "empty?"
    assert_includes src, "finalize!"
  end
end
