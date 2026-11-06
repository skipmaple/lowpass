require "test_helper"

class TranslationPreservationTest < ActiveSupport::TestCase
  test "数据库限制字段摘要和每条目每字段唯一，删除条目级联" do
    item = items(:hn_one)
    row = { item: item, field: "title", input_digest: "a" * 64, assessed_at: Time.current }
    marker = TranslationPreservation.create!(row)
    assert_raises(ActiveRecord::RecordNotUnique) { TranslationPreservation.transaction(requires_new: true) { TranslationPreservation.insert_all!([ marker.attributes.except("id").merge("id" => Lowpass::Uuid.generate) ]) } }
    assert_raises(ActiveRecord::StatementInvalid) { TranslationPreservation.transaction(requires_new: true) { marker.update_columns(field: "content") } }
    assert_raises(ActiveRecord::StatementInvalid) { TranslationPreservation.transaction(requires_new: true) { marker.update_columns(input_digest: "wrong") } }
    item.delete
    assert_not TranslationPreservation.exists?(marker.id)
  end
end
