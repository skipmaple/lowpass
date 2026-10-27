module ApplicationHelper
  # 冷缓存时 Newsreader 要等文字排出来才开始下载，总在首次绘制之后换字、把版面推动（CLS）：
  # 跟文楷界面子集一样先 preload。清单里它的键是 node_modules 里的源路径（@fontsource-variable 引进来的）。
  # 开发时走 Vite 开发服务器，这个路径不在开发服务器的地址里，不 preload。
  NEWSREADER_LATIN = "~/../../node_modules/@fontsource-variable/newsreader/files/newsreader-latin-wght-normal.woff2".freeze

  # 搜索专属模块和依赖与入口并行请求；公共依赖仍由入口负责，避免重复标签。
  def search_page_preload_tag
    return unless controller_path == "searches" && action_name == "show" && !Rails.env.development?

    search = vite_manifest.resolve_entries("pages/Search/Show.tsx")
    application = vite_manifest.resolve_entries("application.tsx", type: :typescript)
    search_only = (search.fetch(:scripts) + search.fetch(:imports)) - (application.fetch(:scripts) + application.fetch(:imports))
    vite_preload_tag(*search_only, crossorigin: "", data: { search_page: true })
  end

  def latin_font_preload_tag
    return if Rails.env.development?

    tag.link(rel: "preload", href: vite_asset_path(NEWSREADER_LATIN), as: "font", type: "font/woff2", crossorigin: "")
  end
end
