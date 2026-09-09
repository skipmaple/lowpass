module Lowpass
  module Uuid
    BASE36_LENGTH = 25 # 36^25 > 2^128

    class << self
      def generate
        hex_to_base36(SecureRandom.uuid_v7.delete("-"))
      end

      def hex_to_base36(hex)
        hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
      end

      def base36_to_hex(base36)
        base36.to_s.to_i(36).to_s(16).rjust(32, "0")
      end

      # 给 fixture 用：按标签生成确定且排在过去的 UUIDv7
      def for_fixture(label)
        fixture_int = Zlib.crc32("fixtures/#{label}") % (2**30 - 1)
        time = Time.utc(2024, 1, 1) + (fixture_int / 1000.0)
        with_timestamp(time, label)
      end

      def with_timestamp(time, seed)
        ms = (time.to_f * 1000)
        ts = ms.to_i
        bytes = 6.times.map { |i| (ts >> (40 - 8 * i)) & 0xff }
        sub = ((ms - ts) * 4096).to_i & 0xfff
        bytes << (((sub >> 8) & 0x0f) | 0x70) << (sub & 0xff)
        rand_b = Digest::MD5.hexdigest(seed)[3...19].to_i(16) & ((2**62) - 1)
        bytes << (((rand_b >> 56) & 0x3f) | 0x80)
        7.times { |i| bytes << ((rand_b >> (48 - 8 * i)) & 0xff) }
        hex_to_base36(bytes.pack("C*").unpack1("H*"))
      end
    end
  end
end
