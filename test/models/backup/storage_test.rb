require "test_helper"

class Backup::StorageTest < ActiveSupport::TestCase
  CONTENT = "encrypted backup bytes".b

  setup do
    @dir = Dir.mktmpdir
    @file = File.join(@dir, "x.dump.enc").tap { |path| File.binwrite(path, CONTENT) }
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "PUT 带 SigV4 签名与两种摘要，请求体就是文件" do
    travel_to Time.utc(2026, 9, 28, 19)
    with_backup_config do
      stub = stub_request(:put, "#{BUCKET}/x.dump.enc").with do |request|
        authorization = request.headers["Authorization"]
        authorization.start_with?("AWS4-HMAC-SHA256 Credential=test-access-key/20260928/auto/s3/aws4_request") &&
          authorization.include?("SignedHeaders=content-md5;content-type;host;x-amz-content-sha256;x-amz-date") &&
          request.headers["X-Amz-Content-Sha256"] == Digest::SHA256.hexdigest(CONTENT) &&
          request.headers["Content-Md5"] == Digest::MD5.base64digest(CONTENT) &&
          request.headers["Content-Type"] == "application/octet-stream" &&
          request.headers["User-Agent"].start_with?("lowpass/") &&
          request.body == CONTENT
      end.to_return(status: 200)

      Backup::Storage.put("x.dump.enc", @file)
      assert_requested stub
    end
  end

  # 路径式（桶名在路径里）与虚拟主机式（桶名在主机名里）同一个写法：对象地址就是 BACKUP_BUCKET_URL 接 /对象名
  test "路径式地址" do
    with_backup_config(BACKUP_ENV.merge("BACKUP_BUCKET_URL" => "https://account.r2.example/lowpass-backup/")) do
      stub = stub_request(:put, "https://account.r2.example/lowpass-backup/x.dump.enc").to_return(status: 200)
      Backup::Storage.put("x.dump.enc", @file)
      assert_requested stub
    end
  end

  test "403 与 429 是终态，带上存储端的错误码" do
    with_backup_config do
      { 403 => "AccessDenied", 429 => "SlowDown" }.each do |status, code|
        stub_request(:put, "#{BUCKET}/x.dump.enc").to_return(status: status, body: "<?xml version=\"1.0\"?><Error><Code>#{code}</Code><Message>no</Message></Error>")
        error = assert_raises(Backup::Error) { Backup::Storage.put("x.dump.enc", @file) }
        assert_not_kind_of Backup::Transient, error
        assert_equal "上传失败（#{status}）：#{code}", error.message
      end
    end
  end

  test "区域不对的重定向不跟：终态" do
    with_backup_config do
      stub_request(:put, "#{BUCKET}/x.dump.enc").to_return(status: 301, body: "<Error><Code>PermanentRedirect</Code></Error>", headers: { "Location" => "https://elsewhere.example/" })
      error = assert_raises(Backup::Error) { Backup::Storage.put("x.dump.enc", @file) }
      assert_equal "上传失败（301）：PermanentRedirect", error.message
    end
  end

  test "5xx、超时与连接失败是暂时性" do
    with_backup_config do
      stub_request(:put, "#{BUCKET}/x.dump.enc").to_return(status: 503, body: "")
      assert_equal "上传失败（503）", assert_raises(Backup::Transient) { Backup::Storage.put("x.dump.enc", @file) }.message

      stub_request(:put, "#{BUCKET}/x.dump.enc").to_timeout
      assert_match(/\A上传没有完成：/, assert_raises(Backup::Transient) { Backup::Storage.put("x.dump.enc", @file) }.message)

      stub_request(:put, "#{BUCKET}/x.dump.enc").to_raise(Errno::ECONNREFUSED)
      assert_raises(Backup::Transient) { Backup::Storage.put("x.dump.enc", @file) }
    end
  end
end
