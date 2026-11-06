require "test_helper"
require "open3"
require "tmpdir"
require "zlib"

class FirstScreenSizeTest < ActiveSupport::TestCase
  setup do
    @build = Dir.mktmpdir("lowpass-first-screen-")
    @manifest = {
      "entrypoints/application.tsx" => { "file" => "application.js", "imports" => [ "shared" ], "css" => [ "shared.css" ] },
      "pages/Daily/Show.tsx" => { "file" => "daily.js", "imports" => [ "shared" ], "css" => [ "daily.css", "shared.css" ] },
      "shared" => { "file" => "shared.js", "css" => [ "shared.css" ] },
      "entrypoints/application.css" => { "file" => "application.css" }
    }
    %w[daybreak duet unfold].zip(%w[a b c]).each do |theme, key|
      @manifest["styles/fonts-#{theme}-content.css"] = { "file" => "#{theme}.css" }
      %w[regular bold].each { |weight| font("#{key}-#{weight}-ui", 100_000) }
      (key == "c" ? %w[body title date] : %w[body display]).each { |role| font("#{key}-latin-#{role}", 1_000) }
    end
    @manifest.each_value do |entry|
      paths = [ entry.fetch("file"), *entry.fetch("css", []) ]
      paths.each { |path| File.write(File.join(@build, path), "fixture #{path}") unless File.exist?(File.join(@build, path)) }
    end
    FileUtils.mkdir_p(File.join(@build, ".vite"))
  end

  teardown { FileUtils.remove_entry(@build) }

  test "三个主题各自遵守用户确认的500KiB门禁" do
    font("a-regular-ui", 300_000)
    output, status = measure
    assert status.success?, output
    assert_equal 3, output.scan("budget 500").length

    font("a-regular-ui", 500_000)
    output, status = measure
    assert_not status.success?, output
  end

  test "日刊和共享静态依赖的CSS只计一次，异步后台CSS不算首屏" do
    css = Random.new(42).bytes(20_000).unpack1("H*")
    File.write(File.join(@build, "daily.css"), css)
    @manifest["pages/Admin/Index.tsx"] = { "file" => "admin.js", "css" => [ "admin.css" ] }
    File.write(File.join(@build, "admin.js"), "not requested")
    File.write(File.join(@build, "admin.css"), Random.new(42).bytes(500_000).unpack1("H*"))
    expected = %w[application.js daily.js shared.js application.css daily.css shared.css].sum do |path|
      Zlib.gzip(File.binread(File.join(@build, path)), level: Zlib::BEST_COMPRESSION).bytesize
    end
    output, status = measure
    assert status.success?, output
    assert_equal 3, output.scan("JS/CSS #{format('%.2f', expected / 1024.0)}").length
  end

  test "日刊声明的CSS缺失时失败" do
    File.delete(File.join(@build, "daily.css"))
    _, status = measure
    assert_not status.success?
  end

  test "日刊静态并入入口时仍统计全部入口依赖和CSS" do
    @manifest.delete("pages/Daily/Show.tsx")
    @manifest.fetch("entrypoints/application.tsx").fetch("css") << "daily.css"
    expected = %w[application.js shared.js application.css daily.css shared.css].sum do |path|
      Zlib.gzip(File.binread(File.join(@build, path)), level: Zlib::BEST_COMPRESSION).bytesize
    end
    output, status = measure
    assert status.success?, output
    assert_equal 3, output.scan("JS/CSS #{format('%.2f', expected / 1024.0)}").length
  end

  private
    def font(name, bytes)
      file = "#{name}.woff2"
      @manifest["fonts/themes/#{file}"] = { "file" => file }
      File.binwrite(File.join(@build, file), "f" * bytes)
    end

    def measure
      File.write(File.join(@build, ".vite/manifest.json"), @manifest.to_json)
      Open3.capture2e(RbConfig.ruby, Rails.root.join("script/first_screen_size").to_s, @build)
    end
end
