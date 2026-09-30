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
          # 周刊的落点跟搜索结果的所在期是同一个值（Item#anchor）；日刊落到条目本身，渲染时现查
          anchor: (item.anchor.slice(0, ANCHOR_LIMIT) if item.issue.kind == "weekly")
        }
      end
  end

  def live_key = [ publication, period_key, source_id, url_hash ]

  # 所在期的标签（R-10.6，同搜索结果）：「2026年9月8日」/「2026年 · 第 36 周 · 工具」
  def where_label = PeriodKey.issue_label(publication, period_key, section: section)
end
