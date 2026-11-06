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
end
