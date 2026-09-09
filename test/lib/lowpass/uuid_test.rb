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
end
