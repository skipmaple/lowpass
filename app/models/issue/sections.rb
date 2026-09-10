module Issue::Sections
  extend ActiveSupport::Concern

  # 整栏（日刊）与整节（周刊）都是这一个写法：先删这个源的旧条目，再整批写新的，别的源不受影响；
  # 传了 issue_no 就只删同一期号的旧条目（同一周两期各占一节，互不覆盖，R41），不传则整源替换（日刊、RSS 周刊源）
  def replace_section!(source, entries, issue_no: nil)
    transaction do
      scope = items.where(source: source)
      scope = scope.where("meta->>'issue_no' = ?", issue_no.to_s) if issue_no
      scope.delete_all
      rows = entries.map { |e| e.to_item_attributes(source: source, issue: self) }
      rows.uniq! { |r| r[:url_hash] }   # 同源重复地址保留首次出现
      Item.insert_all!(rows.map { |r| r.merge(id: Lowpass::Uuid.generate, created_at: Time.current, updated_at: Time.current) }) if rows.any?
    end
  end
end
