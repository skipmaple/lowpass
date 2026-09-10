require "test_helper"

class Lowpass::UuidTest < ActiveSupport::TestCase
  test "generate 返回 25 位 base36" do
    id = Lowpass::Uuid.generate
    assert_equal 25, id.length
    assert_match(/\A[0-9a-z]{25}\z/, id)
  end

  test "先生成的 id 排在后生成的前面" do
    a = Lowpass::Uuid.generate
    sleep 0.002
    b = Lowpass::Uuid.generate
    assert a < b
  end

  test "hex 与 base36 往返一致" do
    hex = "0190f3c2a1b74e1a8c3d1e2f3a4b5c6d"
    assert_equal hex, Lowpass::Uuid.base36_to_hex(Lowpass::Uuid.hex_to_base36(hex))
  end

  test "for_fixture 返回 25 位 base36 字符串" do
    id = Lowpass::Uuid.for_fixture(:hn)
    assert_equal 25, id.length
    assert_match(/\A[0-9a-z]{25}\z/, id)
  end

  test "for_fixture 是确定的（同标签返回同 id）" do
    id1 = Lowpass::Uuid.for_fixture(:hn)
    id2 = Lowpass::Uuid.for_fixture(:hn)
    assert_equal id1, id2
  end

  test "for_fixture 解码为 version 7 的 UUID" do
    id = Lowpass::Uuid.for_fixture(:hn)
    hex = Lowpass::Uuid.base36_to_hex(id)
    version_nibble = hex[12]
    assert_equal "7", version_nibble
  end

  test "for_fixture 生成的 id 排在 generate 之前（fixture 更旧）" do
    fixture_id = Lowpass::Uuid.for_fixture(:hn)
    runtime_id = Lowpass::Uuid.generate
    assert fixture_id < runtime_id
  end

  test "ActiveRecord::FixtureSet.identify(:hn, :uuid) 等于 Lowpass::Uuid.for_fixture(:hn)" do
    fixture_uuid = Lowpass::Uuid.for_fixture(:hn)
    identified = ActiveRecord::FixtureSet.identify(:hn, :uuid)
    assert_equal fixture_uuid, identified
  end

  test "ActiveRecord::FixtureSet.identify(:hn, :string) 等于 Lowpass::Uuid.for_fixture(:hn)" do
    fixture_uuid = Lowpass::Uuid.for_fixture(:hn)
    identified = ActiveRecord::FixtureSet.identify(:hn, :string)
    assert_equal fixture_uuid, identified
  end

  test "ActiveRecord::FixtureSet.identify(:hn) 整数列类型仍然返回整数" do
    identified = ActiveRecord::FixtureSet.identify(:hn)
    assert_instance_of Integer, identified
  end
end
