require "test_helper"

class TranslationCallMetadataTest < ActiveSupport::TestCase
  test "翻译请求必须带范围摘要且数据库拒绝未知目的" do
    attributes = { issue: issues(:daily_0908), item: items(:hn_one), purpose: "translation", operation_key: SecureRandom.uuid,
      input_field: "title", input_digest: "a" * 64, status: "ok" }
    call = ModelCall.create!(attributes)
    assert_equal "translation", call.reload.purpose
    assert_raises(ActiveRecord::StatementInvalid) { ModelCall.transaction(requires_new: true) { call.update_columns(purpose: "other") } }
    assert_raises(ActiveRecord::StatementInvalid) { ModelCall.transaction(requires_new: true) { call.update_columns(input_digest: nil) } }
  end
end
