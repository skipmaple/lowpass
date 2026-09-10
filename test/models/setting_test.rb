require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "没有记录时给默认值" do
    assert_equal "09:00", Setting.get("weekly_time")
  end

  test "存了空值也回落到默认" do
    Setting.set("daily_time", "")

    assert_equal "06:00", Setting.get("daily_time")
  end

  test "set 覆盖已有的键" do
    Setting.set("daily_time", "07:30")

    assert_equal "07:30", Setting.get("daily_time")
    assert_equal 1, Setting.where(key: "daily_time").count
  end
end
