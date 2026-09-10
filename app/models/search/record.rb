# 条目的搜索副本（设计 3.1、第 4 节）：一行一条可见条目，四个可搜列存 NFKC 归一化后的文本
# （全角字母数字标点转半角），展示仍用 items 原文；hidden 的条目没有行。行由 Item 的 Searchable
# 回调、装订的批量写入（Issue::Sections）与 rebuild! 三处维护，都走 index_items!。
class Search::Record < ApplicationRecord
  belongs_to :item
  belongs_to :issue
  belongs_to :source

  LIMITS = { title: 300, section: 100, source_name: 100, summary: 500 }.freeze
  ANCHOR_LIMIT = 120

  # 拉丁词贴着中文时（「用Rust写的」），数据库按 ctype 把汉字也当词字符：`\m` 词首与 word_similarity 的分词
  # 都认不出 Rust 是一个词。索引副本在中外文交界处补一个空格（查询侧拆词本来就按脚本切开，中文二元组
  # 不跨脚本，不受影响），展示仍用 items 原文。
  SCRIPT_GAP = /(?<=[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}])(?=[^\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\s])|(?<=[^\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\s])(?=[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}])/
  # upsert 冲突时更新的列：id 不动，行 id 在第一次索引后就稳定
  COLUMNS = %i[ issue_id source_id publication period_key published_on title section source_name summary anchor ].freeze

  # 查询只搜已发布的期（生成中的期条目已进索引，但读者看不到）
  scope :published, -> { joins(:issue).where(issues: { state: "published" }) }

  class << self
    def index!(item) = index_items!([ item.id ])

    # 批量 upsert：装订一栏十条只发一条语句；hidden 的条目删行；传进来的 id 不存在就跳过
    def index_items!(item_ids)
      items = Item.where(id: item_ids).includes(:issue, :source).to_a
      visible, hidden = items.partition { |item| !item.hidden }
      upsert_all(visible.map { |item| row_for(item) }, unique_by: :item_id, update_only: COLUMNS) if visible.any?
      where(item_id: hidden.map(&:id)).delete_all if hidden.any?
      nil
    end

    # 清空重来（迁移后的一次性步骤 bin/rails search:rebuild、P2 的后台入口）；返回重建后的行数
    def rebuild!
      transaction do
        delete_all
        Item.visible.select(:id).find_in_batches(batch_size: 500) { |batch| index_items!(batch.map(&:id)) }
      end
      count
    end

    private
      def row_for(item)
        {
          id: Lowpass::Uuid.generate,
          item_id: item.id,
          issue_id: item.issue_id,
          source_id: item.source_id,
          publication: item.issue.kind,
          period_key: item.issue.period_key,
          published_on: published_on_for(item),
          title: normalize(item.title, :title),
          section: normalize(item.section, :section),
          source_name: normalize(item.source.name, :source_name),
          summary: normalize(item.summary, :summary),
          # 超长板块名的锚点截到列宽：落不到页面上的锚点好过整栏装订失败
          anchor: (item.anchor.slice(0, ANCHOR_LIMIT) if item.issue.kind == "weekly")
        }
      end

      # 日期筛选的依据（设计 3.1）：日刊取期日期；周刊取条目发布时间的上海日期，没有就取该周周一
      def published_on_for(item)
        if item.issue.kind == "daily"
          PeriodKey.date_of(item.issue.period_key)
        else
          item.published_at&.in_time_zone(PeriodKey::ZONE)&.to_date || PeriodKey.week_range(item.issue.period_key).first
        end
      end

      # NFKC 可能拉长字符串（ﬁ → fi），补空格也会，截回列宽
      def normalize(text, column)
        text&.unicode_normalize(:nfkc)&.gsub(SCRIPT_GAP, " ")&.slice(0, LIMITS.fetch(column))
      end
  end

  def daily? = publication == "daily"

  # 所在期的标签（设计 6.3）：日刊「9月8日」，周刊「第 36 周 · 工具」（板块可空则只写周次）。板块名用 items 原文。
  def where_label
    if daily?
      PeriodKey.date_label(PeriodKey.date_of(period_key))
    else
      [ "第 #{PeriodKey.week_number(period_key)} 周", item.section.presence ].compact.join(" · ")
    end
  end

  def published_label = PeriodKey.date_label(published_on)
end
