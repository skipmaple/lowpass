require "test_helper"
require "open3"
require "tmpdir"
require "zlib"

class FrontendDeltaSizeTest < ActiveSupport::TestCase
  setup do
    @build = Dir.mktmpdir("lowpass-budget-")
    reference = Zlib::GzipReader.open(Rails.root.join("vendor/frontend-budget/aee2d5f.json.gz")) { |file| JSON.parse(file.read) }
    @manifest = {}
    reference.fetch("files").each do |entry|
      path = File.join(@build, entry.fetch("path"))
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, entry.fetch("content"))
      @manifest[entry.fetch("path")] = { "file" => entry.fetch("path") }
    end
    FileUtils.mkdir_p(File.join(@build, ".vite"))
  end

  teardown { FileUtils.remove_entry(@build) }

  test "同一原始产物在当前压缩运行时的累计增量为零" do
    output, status = measure
    assert status.success?, output
    assert_equal 2, output.scan("增量 +0 B").length
  end

  test "异步页面的新增CSS也受累计预算约束" do
    @manifest["lazy.css"] = { "file" => "lazy.css" }
    File.write(File.join(@build, "lazy.css"), Random.new(42).bytes(100_000).unpack1("H*"))
    output, status = measure
    assert_not status.success?, output
    assert_includes output, "CSS:"
    assert_includes output, "超出或产物缺失"
  end

  test "旧指纹缓存不冒充当前manifest的资源" do
    File.write(File.join(@build, "obsolete.js"), Random.new(42).bytes(500_000).unpack1("H*"))
    output, status = measure
    assert status.success?, output
    assert_equal 2, output.scan("增量 +0 B").length
  end

  test "当前manifest引用的资源缺失时失败" do
    @manifest["missing.css"] = { "file" => "missing.css" }
    _, status = measure
    assert_not status.success?
  end

  private
    def measure
      File.write(File.join(@build, ".vite/manifest.json"), @manifest.to_json)
      Open3.capture2e(RbConfig.ruby, Rails.root.join("script/frontend_delta_size").to_s, @build)
    end
end
