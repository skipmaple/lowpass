class Item < ApplicationRecord
  include Searchable

  belongs_to :source
  belongs_to :issue

  validates :title, presence: true, length: { maximum: 300 }
  validates :url, presence: true, length: { maximum: 2048 }, format: { with: %r{\Ahttps?://\S+\z}i }
  validates :url_hash, presence: true, length: { is: 64 }
  validates :summary, length: { maximum: 500 }, allow_nil: true

  scope :visible, -> { where(hidden: false) }
  scope :ranked,  -> { order(:rank, :created_at) }

  # 周刊页板块的落点（R-2.5 目录）也是搜索结果「所在期」链接的 fragment，Issue::Presenting 与 Search::Record
  # 共用这一处。阮一峰的板块 slug 由适配器按 GitHub 的锚点算法算好放在 meta.anchor；同一周两期各占一节
  # （R41）时带上期号，两节里同名板块才不撞。没有板块的源（RSS 周刊源、降级 stub）落到这一节的头上。
  def anchor
    slug = meta["anchor"].presence
    number = meta["issue_no"].presence
    if slug && number
      "issue-#{number}-#{slug}"
    elsif slug
      slug
    else
      "source-#{source_id}"
    end
  end
end
