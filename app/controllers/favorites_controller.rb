# 收藏（PRD 5.10）。index 是收藏页；create / destroy 是条目上那颗书签的两个动作：前端用 fetch 调、这里回 JSON
# （跟 search/clicks、测试抓取一样不是页面）。资源的键是链接的 url_hash（一人一链接一条，D27），不是行 id。
# 书签的动作按用户每分钟 60 次（R-10.10），收藏页本身不限。
class FavoritesController < ApplicationController
  rate_limit to: 60, within: 1.minute, by: -> { Current.user.id }, with: -> { head :too_many_requests }, only: [ :create, :destroy ]

  # R-10.6 按收藏时间倒序，每页 20 条；页码超过最后一页（取消后页数变少、手改地址）跳到最后一页
  def index
    scope = Current.user.favorites.listed
    pages = (scope.count.to_f / Favorite::PER_PAGE).ceil

    if pages.positive? && page_number > pages
      redirect_to favorites_path(page: pages)
    else
      favorites = scope.newest_first.includes(:source).offset((page_number - 1) * Favorite::PER_PAGE).limit(Favorite::PER_PAGE).to_a
      live = Favorite.live_items(favorites)

      render inertia: "Favorites/Index", props: {
        entries: favorites.map { |favorite| entry_props(favorite, live[favorite.live_key]) },
        favorites: favorites.map(&:url_hash),
        page: page_number,
        pages: pages
      }.merge(footer_props)
    end
  end

  # 收藏一条条目；或者凭取消时拿到的凭据，把刚取消的那条原样恢复（R-10.7）
  def create
    favorite = if params[:undo].present?
      Favorite.restore(Current.user, params[:undo])
    elsif item = Item.visible.find_by(id: params[:item_id].to_s)
      Favorite.keep(Current.user, item)
    end

    if favorite
      render json: { url_hash: favorite.url_hash }, status: :created
    else
      head :not_found
    end
  end

  # 取消是真删，回一张恢复凭据。已经不在了（重复提交、别人的链接）也不报错（R-10.5）
  def destroy
    if favorite = Current.user.favorites.find_by(url_hash: params[:url_hash])
      favorite.destroy!
      render json: { undo: favorite.undo_token }
    else
      head :no_content
    end
  end

  private
    # create / destroy 是 fetch 发来的：被 302 带去登录页的话 fetch 会跟着跳，拿回一页 HTML 当成功。
    # 会话过期时给 401，前端据此整页去登录（PRD 5.10 边界）；收藏页本身（GET）照常跳 /login?next=
    def request_authentication
      if request.get? || request.head?
        super
      else
        head :unauthorized
      end
    end

    # ?page[]=… 这类不是数字的值都当第 1 页
    def page_number
      @page_number ||= [ Integer(params[:page].to_s, 10, exception: false) || 1, 1 ].max
    end

    # 行的字段照搜索结果行（R-10.6）。条目还在就用它现在的译文：译文可能是收藏之后才生成的（R-9.10）
    def entry_props(favorite, item)
      {
        url_hash: favorite.url_hash,
        publication: favorite.publication,
        source_name: favorite.source.name,
        where: { label: favorite.where_label, href: where_href(favorite, item) },
        url: favorite.url,
        title: favorite.title,
        title_zh: item&.title_zh.presence || favorite.title_zh,
        snippet: Search::Highlighter.excerpt(favorite.summary),
        summary_zh: item&.summary_zh.presence || favorite.summary_zh
      }
    end

    # 所在期（同搜索结果）：日刊带 ?source= 切到那一栏，条目还在就落到它；周刊落到板块锚点
    def where_href(favorite, item)
      if favorite.publication == "daily"
        daily_issue_path(favorite.period_key, source: favorite.source_id, anchor: ("item-#{item.id}" if item))
      else
        weekly_issue_path(favorite.period_key, anchor: favorite.anchor)
      end
    end
end
