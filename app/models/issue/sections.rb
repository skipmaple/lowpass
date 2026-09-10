module Issue::Sections
  extend ActiveSupport::Concern

  # 整栏（日刊）与整节（周刊）都是这一个写法：先删这个源在本期的旧条目，再整批写新的，别的源不受影响
  def replace_section!(source, entries)
    transaction do
      items.where(source: source).delete_all
      rows = entries.map { |e| e.to_item_attributes(source: source, issue: self) }
      rows.uniq! { |r| r[:url_hash] }   # 同源重复地址保留首次出现
      Item.insert_all!(rows.map { |r| r.merge(id: Lowpass::Uuid.generate, created_at: Time.current, updated_at: Time.current) }) if rows.any?
    end
  end
end
