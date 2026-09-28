require "test_helper"

class Backup::ConfigTest < ActiveSupport::TestCase
  teardown { Backup::Config.load!({}) }

  test "五项齐全才算配好；页面上只有主机路径与指纹，没有密钥" do
    Backup::Config.load!(BACKUP_ENV)

    assert Backup::Config.configured?
    assert_empty Backup::Config.problems
    assert_equal "lowpass-backup.storage.example/daily", Backup::Config.storage_label
    assert_equal Lowpass::BackupCipher.fingerprint(Lowpass::BackupCipher.key("ab" * 32)), Backup::Config.key_fingerprint
    assert_equal 32, Backup::Config.encryption_key.bytesize
  end

  test "一个都没配：不算配好，也不算给过" do
    Backup::Config.load!({})

    assert_not Backup::Config.configured?
    assert_not Backup::Config.any_given?
    assert_nil Backup::Config.storage_label
    assert_nil Backup::Config.key_fingerprint
  end

  # Kamal 对 .kamal/secrets 里没值的变量注入空串
  test "空串与空白等于没配" do
    Backup::Config.load!(BACKUP_ENV.merge("BACKUP_REGION" => "", "BACKUP_SECRET_ACCESS_KEY" => "  "))

    assert_not Backup::Config.configured?
    assert_equal [ "缺 BACKUP_REGION", "缺 BACKUP_SECRET_ACCESS_KEY" ], Backup::Config.problems
  end

  test "地址：https；本机 http 可以；别处 http、带查询或账号口令都不行" do
    { "http://127.0.0.1:9000/lowpass" => true, "http://localhost:9000/lowpass" => true, "http://storage.example/lowpass" => false,
      "https://storage.example/lowpass?x=1" => false, "https://key:secret@storage.example/lowpass" => false, "ftp://storage.example" => false,
      "https:///lowpass" => false }.each do |url, valid|
      Backup::Config.load!(BACKUP_ENV.merge("BACKUP_BUCKET_URL" => url))
      assert_equal valid, Backup::Config.configured?, url
      assert_equal [ "BACKUP_BUCKET_URL 必须是 https 地址" ], Backup::Config.problems, url unless valid
    end
  end

  test "末尾的斜杠去掉：对象地址是它后面接 /对象名" do
    Backup::Config.load!(BACKUP_ENV.merge("BACKUP_BUCKET_URL" => "#{BUCKET}//"))
    assert_equal BUCKET, Backup::Config.bucket_url
  end

  test "区域与加密密钥的格式" do
    Backup::Config.load!(BACKUP_ENV.merge("BACKUP_REGION" => "Asia East", "BACKUP_ENCRYPTION_KEY" => "not-hex"))

    assert_equal [ "BACKUP_REGION 只能有小写字母、数字与连字符", "BACKUP_ENCRYPTION_KEY 必须是 64 位十六进制（openssl rand -hex 32）" ], Backup::Config.problems
    assert_nil Backup::Config.key_fingerprint
  end

  test "该不该有备份：production 一定要；别的环境配了才算" do
    Backup::Config.load!({})
    assert_not Backup.expected?

    Backup::Config.load!("BACKUP_REGION" => "auto")
    assert Backup.expected?

    Backup::Config.load!({})
    Rails.env.stubs(:production?).returns(true)
    assert Backup.expected?
  end
end
