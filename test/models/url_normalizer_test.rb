require "test_helper"

class UrlNormalizerTest < ActiveSupport::TestCase
  test "小写协议与主机、去默认端口、去 fragment、去跟踪参数、参数排序、去尾斜杠" do
    url = "HTTP://Example.COM:80/a/b/?utm_source=x&b=2&a=1#top"
    assert_equal "http://example.com/a/b?a=1&b=2", UrlNormalizer.normalize(url)
  end

  test "根路径保留斜杠，http 与 https 同哈希" do
    assert_equal "http://example.com/", UrlNormalizer.normalize("http://example.com/")
    assert_equal "https://example.com/x", UrlNormalizer.normalize("https://example.com/x")
    assert_equal UrlNormalizer.hash("http://example.com/x"), UrlNormalizer.hash("https://example.com/x")
  end
end
