module ApplicationHelper
  # 冷缓存时 Newsreader 要等文字排出来才开始下载，总在首次绘制之后换字、把版面推动（CLS）：
  # 跟文楷界面子集一样先 preload。清单里它的键是 node_modules 里的源路径（@fontsource-variable 引进来的）。
  # 开发时走 Vite 开发服务器，这个路径不在开发服务器的地址里，不 preload。
  NEWSREADER_LATIN = "~/../../node_modules/@fontsource-variable/newsreader/files/newsreader-latin-wght-normal.woff2".freeze

  def latin_font_preload_tag
    return if Rails.env.development?

    tag.link(rel: "preload", href: vite_asset_path(NEWSREADER_LATIN), as: "font", type: "font/woff2", crossorigin: "")
  end
end
