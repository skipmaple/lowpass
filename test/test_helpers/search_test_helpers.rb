# 搜索测试的条目工厂：走 Item.create!，Searchable 的 after_create_commit 把它送进 Search::Record
# （transactional tests 里 after_commit 照样触发）。默认落在已发布的日刊 2026-09-08、来源 Hacker News。
module SearchTestHelpers
  def index_item(title, issue: issues(:daily_0908), source: sources(:hn), **attrs)
    url = "https://example.com/#{SecureRandom.hex(6)}"
    issue.items.create!({ source: source, title: title, url: url, url_hash: UrlNormalizer.url_hash(url), fetched_at: Time.current, rank: 1 }.merge(attrs))
  end

  def search(q, **params) = Search::Runner.call(Search::Query.parse({ q: q }.merge(params)))

  def found_titles(result) = result.entries.map { |entry| entry.record.item.title }
end
