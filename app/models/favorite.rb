# 收藏（PRD 5.10）：读者留下的一条链接。按 url_hash 认，一人一链接一条（D27）；收藏时把条目抄成快照，
# 不引用条目行——管理员重抓会整栏换掉条目的 id（Issue::Sections#replace_section!），引用了就会丢。
# 只有本人可见（R-10.8）：读写都从 user.favorites 进来。
class Favorite < ApplicationRecord
  include Favorite::Undoing

  PER_PAGE = 20
  ANCHOR_LIMIT = 120

  belongs_to :user
  belongs_to :source

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  # R-10.9 链接有条目被下架（F-29）就不列；收藏记录留着，恢复上架后重新出现
  scope :listed, -> { where.not(url_hash: Item.where(hidden: true).select(:url_hash)) }

  # 搜索先于分页，在本人的收藏快照以及同一期当前条目的后补译文中找回。
  # 重抓移除原条目后快照仍能命中；LIKE 特殊字符按普通文字处理。
  scope :matching, ->(query) {
    if query.present?
      term = "%#{sanitize_sql_like(query)}%"
      joins(:source).where(<<~SQL.squish, term: term)
        concat_ws(' ', favorites.title, favorites.title_zh, favorites.summary, favorites.summary_zh, sources.name) ILIKE :term
        OR EXISTS (
          SELECT 1 FROM items
          INNER JOIN issues ON issues.id = items.issue_id
          WHERE items.url_hash = favorites.url_hash
            AND items.source_id = favorites.source_id
            AND issues.kind = favorites.publication
            AND issues.period_key = favorites.period_key
            AND items.hidden = FALSE
            AND concat_ws(' ',
              CASE WHEN items.title = favorites.title THEN items.title_zh END,
              CASE WHEN items.summary IS NOT DISTINCT FROM favorites.summary THEN items.summary_zh END
            ) ILIKE :term
        )
      SQL
    else
      all
    end
  }

  class << self
    # 收藏一条条目。同一链接已经收藏过就返回原来那条：重复提交不报错（R-10.5），收藏时间与所在期也不变
    def keep(user, item)
      user.favorites.create_with(snapshot_of(item)).find_or_create_by!(url_hash: item.url_hash)
    end

    # 这些收藏对应的条目现在还在不在，按（刊物、周期键、来源、链接）对上号。
    # 条目 id 不存：重抓会换掉它，每次现查——译文可能是收藏之后才生成的，日刊的所在期要落到条目锚点
    def live_items(favorites)
      Item.visible.where(url_hash: favorites.map(&:url_hash)).includes(:issue)
        .index_by { |item| [ item.issue.kind, item.issue.period_key, item.source_id, item.url_hash ] }
    end

    private
      def snapshot_of(item)
        {
          url: item.url, title: item.title, title_zh: item.title_zh, summary: item.summary, summary_zh: item.summary_zh,
          source_id: item.source_id, publication: item.issue.kind, period_key: item.issue.period_key, section: item.section,
          # 周刊的板块锚点作为条目消失后的回退；实际条目 id 渲染时现查。
          anchor: (item.anchor.slice(0, ANCHOR_LIMIT) if item.issue.kind == "weekly")
        }
      end
  end

  def live_key = [ publication, period_key, source_id, url_hash ]

  # 所在期的标签（R-10.6，同搜索结果）：「2026年9月8日」/「2026年 · 第 36 周 · 工具」
  def where_label = PeriodKey.issue_label(publication, period_key, section: section)
end
