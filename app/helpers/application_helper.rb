module ApplicationHelper
  # Only the saved theme is preloaded; a first visit uses A. The browser chooses
  # before CSS paints, without sending a presentation preference to the server.
  def theme_font_preloads
    {
      daybreak: %w[a-regular-ui a-bold-ui a-latin-body a-latin-display],
      duet: %w[b-regular-ui b-bold-ui b-latin-body b-latin-display],
      unfold: %w[c-regular-ui c-bold-ui c-latin-body c-latin-title c-latin-date]
    }.transform_values do |fonts|
      fonts.map { |font| vite_asset_path("fonts/themes/#{font}.woff2") }
    end
  end

  # 搜索专属模块和依赖与入口并行请求；公共依赖仍由入口负责，避免重复标签。
  def search_page_preload_tag
    return unless controller_path == "searches" && action_name == "show" && !Rails.env.development?

    search = vite_manifest.resolve_entries("pages/Search/Show.tsx")
    application = vite_manifest.resolve_entries("application.tsx", type: :typescript)
    search_only = (search.fetch(:scripts) + search.fetch(:imports)) - (application.fetch(:scripts) + application.fetch(:imports))
    vite_preload_tag(*search_only, crossorigin: "", data: { search_page: true })
  end
end
