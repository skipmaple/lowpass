require "test_helper"

class FaviconTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:drew)) }

  test "SVG renders the LP stamp on a round canvas with a larger monogram" do
    document = Nokogiri::XML(Rails.root.join("public/icon.svg").read) { |config| config.strict }
    svg = document.root
    fills = document.xpath("//*[@fill]").map { |node| node["fill"]&.upcase }.compact
    circles = document.xpath("//*[local-name()='circle']")
    monogram_paths = document.xpath("//*[local-name()='path']")
    monogram = monogram_paths.first.parent

    assert_equal "svg", svg.name
    assert_equal "0 0 512 512", svg["viewBox"]
    assert_equal "Lowpass", document.at_xpath("//*[local-name()='title']")&.text
    assert_includes fills, "#1D1D1B"
    assert_includes fills, "#E8E3DA"
    assert_empty document.xpath("//*[local-name()='rect']")
    assert_equal [ "256", "232", "184" ], circles.map { |circle| circle["r"] }
    assert_equal "24 24", circles.last["stroke-dasharray"]
    assert_empty document.xpath("//*[local-name()='text']")
    assert_equal 2, monogram_paths.size
    assert monogram_paths.all? { |path| path["d"].present? }
    assert_operator monogram["transform"][/scale\(([^)]+)\)/, 1].to_f, :>=, 1.5
  end

  test "PNG fallback remains 512 pixels square with transparency" do
    png = Rails.root.join("public/icon.png").binread

    assert_equal "\x89PNG\r\n\x1A\n".b, png.byteslice(0, 8)
    assert_equal [ 512, 512 ], png.byteslice(16, 8).unpack("NN")
    assert_equal 6, png.getbyte(25), "PNG color type must include an alpha channel"
  end

  test "rendered layout exposes versioned favicon and Apple touch icon links" do
    get daily_issue_path("2026-09-08")

    assert_response :success
    document = Nokogiri::HTML5(response.body)
    icons = document.css('link[rel="icon"]').to_h { |link| [ link["type"], link["href"] ] }
    apple_touch_icon = document.at_css('link[rel="apple-touch-icon"]')

    assert_equal "/icon.png?v=3", icons["image/png"]
    assert_equal "/icon.svg?v=3", icons["image/svg+xml"]
    assert_equal "/icon.png?v=3", apple_touch_icon&.[]("href")
  end
end
