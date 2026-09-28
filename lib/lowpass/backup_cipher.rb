require "digest"
require "openssl"

module Lowpass
  # 备份文件的加密格式（设计 docs/superpowers/specs/2026-09-28-p3-backup-health-design.md §2.3）：
  #
  #   "LPBK" · 版本 1 · 密钥指纹 8 字节 · IV 12 字节 · AES-256-GCM 密文 · 认证标签 16 字节
  #
  # 前三项作为附加认证数据，一起受标签保护；按 1 MB 分块流式加解密，备份再大也不整份读进内存。
  # 只依赖标准库：script/decrypt_backup 直接 require 这个文件，服务器整个没了也能在别的机器上解开（E14）
  module BackupCipher
    Error = Class.new(StandardError)

    MAGIC = "LPBK".b
    VERSION = 1
    FINGERPRINT_BYTES = 8
    HEADER_BYTES = MAGIC.bytesize + 1 + FINGERPRINT_BYTES
    IV_BYTES = 12
    TAG_BYTES = 16
    CHUNK = 1024 * 1024
    KEY = /\A\h{64}\z/

    class << self
      # BACKUP_ENCRYPTION_KEY 是 64 位十六进制（openssl rand -hex 32），这里换成 32 字节的密钥
      def key(hex)
        raise Error, "密钥必须是 64 位十六进制（openssl rand -hex 32）" unless hex.to_s.match?(KEY)
        [ hex ].pack("H*")
      end

      # 密钥 SHA-256 的前 8 字节：写进文件头，解密时先比它，拿错密钥能直接说清楚是哪一把
      def fingerprint(key) = Digest::SHA256.hexdigest(key)[0, FINGERPRINT_BYTES * 2]

      def encrypt(source, target, key:)
        cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
        cipher.key = key
        iv = cipher.random_iv
        header = MAGIC + [ VERSION ].pack("C") + [ fingerprint(key) ].pack("H*")
        cipher.auth_data = header
        File.open(target, "wb") do |output|
          output.write(header, iv)
          File.open(source, "rb") do |input|
            while (chunk = input.read(CHUNK))
              output.write(cipher.update(chunk))
            end
          end
          output.write(cipher.final, cipher.auth_tag)
        end
      end

      # 先写到 target.partial，标签校验通过才改名：文件被截断、被改动或者拿错密钥，都不会留下一份看着能用的输出
      def decrypt(source, target, key:)
        partial = "#{target}.partial"
        File.open(source, "rb") do |input|
          header = input.read(HEADER_BYTES).to_s
          check_header(header, key)
          iv = input.read(IV_BYTES).to_s
          length = input.size - HEADER_BYTES - IV_BYTES - TAG_BYTES
          raise Error, "备份文件不完整" if iv.bytesize < IV_BYTES || length.negative?

          cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
          cipher.key = key
          cipher.iv = iv
          cipher.auth_tag = tag_of(input)
          cipher.auth_data = header
          File.open(partial, "wb") do |output|
            while length.positive?
              chunk = input.read([ CHUNK, length ].min)
              length -= chunk.bytesize
              output.write(cipher.update(chunk))
            end
            output.write(cipher.final)
          end
        end
        File.rename(partial, target)
      rescue OpenSSL::Cipher::CipherError
        raise Error, "备份文件损坏或被改动（认证标签对不上）"
      ensure
        File.delete(partial) if File.exist?(partial)
      end

      private
        def check_header(header, key)
          raise Error, "不是 lowpass 备份文件" unless header.bytesize == HEADER_BYTES && header.start_with?(MAGIC)
          raise Error, "不认识的备份格式版本 #{header.getbyte(MAGIC.bytesize)}" unless header.getbyte(MAGIC.bytesize) == VERSION

          stored = header.byteslice(MAGIC.bytesize + 1, FINGERPRINT_BYTES).unpack1("H*")
          raise Error, "密钥不对：这份备份是用指纹 #{stored} 的密钥加密的，给的密钥指纹是 #{fingerprint(key)}" unless stored == fingerprint(key)
        end

        # 标签在文件末尾：读出来再回到密文开头
        def tag_of(input)
          position = input.pos
          input.seek(-TAG_BYTES, IO::SEEK_END)
          input.read(TAG_BYTES).tap { input.seek(position) }
        end
    end
  end
end
