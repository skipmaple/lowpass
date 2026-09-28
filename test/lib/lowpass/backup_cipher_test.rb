require "test_helper"

class Lowpass::BackupCipherTest < ActiveSupport::TestCase
  KEY = Lowpass::BackupCipher.key("ab" * 32)
  OTHER_KEY = Lowpass::BackupCipher.key("cd" * 32)

  setup { @dir = Dir.mktmpdir }
  teardown { FileUtils.remove_entry(@dir) }

  test "往返：跨块的内容原样回来，密文里看不到原文" do
    plain = file("plain", "lowpass " * (Lowpass::BackupCipher::CHUNK / 4) + "tail")
    Lowpass::BackupCipher.encrypt(plain, path("enc"), key: KEY)
    Lowpass::BackupCipher.decrypt(path("enc"), path("out"), key: KEY)

    assert_equal File.binread(plain), File.binread(path("out"))
    assert_not_includes File.binread(path("enc")), "lowpass lowpass"
    overhead = Lowpass::BackupCipher::HEADER_BYTES + Lowpass::BackupCipher::IV_BYTES + Lowpass::BackupCipher::TAG_BYTES
    assert_equal File.size(plain) + overhead, File.size(path("enc"))
  end

  test "空文件也能往返" do
    Lowpass::BackupCipher.encrypt(file("plain", ""), path("enc"), key: KEY)
    Lowpass::BackupCipher.decrypt(path("enc"), path("out"), key: KEY)
    assert_equal "", File.binread(path("out"))
  end

  test "文件头：魔数、版本、密钥指纹" do
    Lowpass::BackupCipher.encrypt(file("plain", "x"), path("enc"), key: KEY)
    header = File.binread(path("enc"), Lowpass::BackupCipher::HEADER_BYTES)

    assert header.start_with?("LPBK".b)
    assert_equal 1, header.getbyte(4)
    assert_equal Lowpass::BackupCipher.fingerprint(KEY), header.byteslice(5, 8).unpack1("H*")
    assert_match(/\A\h{16}\z/, Lowpass::BackupCipher.fingerprint(KEY))
  end

  test "密钥不对：报出两边的指纹，不留输出" do
    Lowpass::BackupCipher.encrypt(file("plain", "secret"), path("enc"), key: KEY)
    error = assert_raises(Lowpass::BackupCipher::Error) { Lowpass::BackupCipher.decrypt(path("enc"), path("out"), key: OTHER_KEY) }

    assert_includes error.message, Lowpass::BackupCipher.fingerprint(KEY)
    assert_includes error.message, Lowpass::BackupCipher.fingerprint(OTHER_KEY)
    assert_empty Dir.children(@dir) - [ "plain", "enc" ]
  end

  test "密文被改：认证失败，不留输出" do
    Lowpass::BackupCipher.encrypt(file("plain", "secret " * 100), path("enc"), key: KEY)
    bytes = File.binread(path("enc"))
    bytes.setbyte(40, bytes.getbyte(40) ^ 1)
    File.binwrite(path("enc"), bytes)

    error = assert_raises(Lowpass::BackupCipher::Error) { Lowpass::BackupCipher.decrypt(path("enc"), path("out"), key: KEY) }
    assert_includes error.message, "损坏或被改动"
    assert_empty Dir.children(@dir) - [ "plain", "enc" ]
  end

  test "被截断：报错" do
    Lowpass::BackupCipher.encrypt(file("plain", "secret " * 100), path("enc"), key: KEY)
    File.truncate(path("enc"), 30)

    assert_raises(Lowpass::BackupCipher::Error) { Lowpass::BackupCipher.decrypt(path("enc"), path("out"), key: KEY) }
    assert_not File.exist?(path("out"))
  end

  test "不是备份文件" do
    error = assert_raises(Lowpass::BackupCipher::Error) { Lowpass::BackupCipher.decrypt(file("plain", "PGDMP custom dump"), path("out"), key: KEY) }
    assert_equal "不是 lowpass 备份文件", error.message
  end

  test "密钥必须是 64 位十六进制" do
    [ nil, "", "ab" * 31, "zz" * 32 ].each do |value|
      assert_raises(Lowpass::BackupCipher::Error) { Lowpass::BackupCipher.key(value) }
    end
    assert_equal 32, Lowpass::BackupCipher.key("AB" * 32).bytesize
  end

  test "解密脚本不启动应用：只 require 这一个文件" do
    Lowpass::BackupCipher.encrypt(file("plain", "restore me"), path("enc"), key: KEY)
    script = Rails.root.join("script/decrypt_backup").to_s
    output = IO.popen({ "BACKUP_ENCRYPTION_KEY" => "ab" * 32, "RUBYOPT" => nil }, [ RbConfig.ruby, "--disable-gems", script, path("enc"), path("out") ], err: [ :child, :out ], &:read)

    assert $?.success?, output
    assert_equal "restore me", File.binread(path("out"))
  end

  private
    def path(name) = File.join(@dir, name)

    def file(name, content)
      path(name).tap { |target| File.binwrite(target, content) }
    end
end
