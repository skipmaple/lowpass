module Issue::Sections
  extend ActiveSupport::Concern

  # 整栏（日刊）与整节（周刊的阮一峰）都是这一个写法：先删这个源的旧条目，再整批写新的，别的源不受影响；
  # 传了 issue_no 就只删同一期号的旧条目（同一周两期各占一节，互不覆盖，R41），不传则整源替换。
  # 返回没能落成行的条目数（同源重复地址），调用方计进 dropped_count。
  def replace_section!(source, entries, issue_no: nil)
    transaction do
      scope = items.where(source: source)
      scope = scope.where("meta->>'issue_no' = ?", issue_no.to_s) if issue_no
      scope.delete_all
      write_rows(section_rows(source, entries), entries)
    end
  end

  # R-2.8 周刊的 RSS 节只追加：这一节可能已经发布了几天，整节重写会把周初的条目挤掉（源配置的
  # count 封顶），也会换掉还活着的条目 id，等于事后改写已发布的期（R-1.4）。已经入库的地址跳过，
  # 新的接在这一源现有的 rank 后面。返回跳过的条目数。
  def append_section!(source, entries)
    transaction do
      stored = items.where(source: source).pluck(:url_hash).to_set
      rows = section_rows(source, entries).reject { |row| stored.include?(row[:url_hash]) }
      next_rank = items.where(source: source).maximum(:rank).to_i + 1
      rows.each_with_index { |row, offset| row[:rank] = next_rank + offset }
      write_rows(rows, entries)
    end
  end

  private
    # 同源重复地址保留首次出现：(source, issue, url_hash) 上有唯一索引，重复地址会让整批写入失败
    def section_rows(source, entries)
      entries.map { |entry| entry.to_item_attributes(source: source, issue: self) }.uniq { |row| row[:url_hash] }
    end

    def write_rows(rows, entries)
      Item.insert_all!(rows.map { |row| row.merge(id: Lowpass::Uuid.generate, created_at: Time.current, updated_at: Time.current) }) if rows.any?
      entries.size - rows.size
    end
end
