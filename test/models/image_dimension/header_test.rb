require "test_helper"

class ImageDimension::HeaderTest < ActiveSupport::TestCase
  test "PNG 扫描到 IDAT 头后给出天然尺寸而不需要像素正文" do
    assert_equal [ 640, 480 ], ImageDimension::Header.parse(png(640, 480))
    assert_equal [ 100_000, 1 ], ImageDimension::Header.parse(png(100_000, 1))
  end

  test "PNG 处理 IDAT 前的 EXIF 方向并拒绝只有 IHDR 或不可靠元数据" do
    [ :little, :big ].each do |endian|
      assert_equal [ 480, 640 ], ImageDimension::Header.parse(png(640, 480, before: png_chunk("eXIf", tiff(6, endian: endian))))
    end
    assert_nil ImageDimension::Header.parse(png(640, 480).byteslice(0, 33))
    assert_nil ImageDimension::Header.parse(png(640, 480, before: png_chunk("eXIf", tiff(9))))
    assert_nil ImageDimension::Header.parse(png(640, 480, before: png_chunk("eXIf", tiff(6)) * 2))
    assert_nil ImageDimension::Header.parse(png(640, 480, before: [ 1000 ].pack("N") + "eXIf"))
    assert_nil ImageDimension::Header.parse(png(640, 480, before: png_chunk("eXIf", tiff(6)).tap { |chunk| chunk.setbyte(12, 255) }))
    assert_nil ImageDimension::Header.parse(png(640, 480, before: png_chunk("IEND", "".b)))
    assert_nil ImageDimension::Header.parse(png(640, 480, before: png_chunk("BADH", "".b)))
  end

  test "PNG 跳过已校验的辅助块" do
    assert_equal [ 640, 480 ], ImageDimension::Header.parse(png(640, 480, before: png_chunk("tEXt", "title\0hello".b)))
  end

  test "PNG 拒绝坏校验和 非法头部与不合理尺寸" do
    broken_crc = png(640, 480).dup
    broken_crc.setbyte(32, broken_crc.getbyte(32) ^ 1)
    [ broken_crc, png(0, 20), png(100_001, 20), png(20, 100_001), png(20, 20, depth: 3), png(20, 20, color: 7) ].each do |bytes|
      assert_nil ImageDimension::Header.parse(bytes)
    end
  end

  test "GIF87a 与 GIF89a 使用逻辑画布而不是首帧尺寸" do
    %w[ GIF87a GIF89a ].each do |signature|
      assert_equal [ 320, 600 ], ImageDimension::Header.parse(signature.b + [ 320, 600, 0, 0, 0 ].pack("vvCCC"))
    end
    assert_nil ImageDimension::Header.parse("GIF89a".b + [ 0, 600, 0, 0, 0 ].pack("vvCCC"))
  end

  test "JPEG 跳过完整 APP 段并读取基线和渐进帧尺寸" do
    [ 0xc0, 0xc1, 0xc2 ].each do |marker|
      assert_equal [ 640, 480 ], ImageDimension::Header.parse(jpeg(marker: marker, before: segment(0xe0, "JFIF\0".b)))
    end
  end

  test "JPEG 只有 SOF 不足以排除后续 EXIF 方向" do
    assert_nil ImageDimension::Header.parse("\xff\xd8".b + frame)
    assert_nil ImageDimension::Header.parse("\xff\xd8".b + frame + "\xff\xda\0\x08\x01".b)
  end

  test "JPEG 对大小端 EXIF 的 5 到 8 方向交换宽高" do
    [ :little, :big ].each do |endian|
      (1..8).each do |orientation|
        expected = orientation >= 5 ? [ 480, 640 ] : [ 640, 480 ]
        assert_equal expected, ImageDimension::Header.parse(jpeg(after: exif(orientation, endian: endian)))
      end
    end
  end

  test "JPEG 拒绝损坏 不可靠或相互冲突的 EXIF" do
    [ exif(0), exif(9), segment(0xe1, "Exif\0\0II\x2a\0\xff\xff\xff\x7f".b), exif(6) + exif(1) ].each do |metadata|
      assert_nil ImageDimension::Header.parse(jpeg(before: metadata))
    end
    assert_nil ImageDimension::Header.parse(jpeg(before: segment(0xe1, "Exif\0\0".b)))
  end

  test "JPEG 拒绝零尺寸 畸形段和非帧标记" do
    assert_nil ImageDimension::Header.parse(jpeg(width: 0))
    assert_nil ImageDimension::Header.parse(jpeg(height: 0))
    assert_nil ImageDimension::Header.parse("\xff\xd8\xff\xe0\0\x01".b + frame + scan)
    assert_nil ImageDimension::Header.parse("\xff\xd8\xff\xd9".b)
    assert_nil ImageDimension::Header.parse("\xff\xd8\xff\xc4\0\x05abc".b + scan)
  end

  test "WebP 识别 VP8 VP8L 和扩展画布的头部" do
    assert_equal [ 640, 480 ], ImageDimension::Header.parse(webp("VP8 ", "\x10\0\0\x9d\x01\x2a".b + [ 640, 480 ].pack("vv")))
    bits = 639 | (479 << 14)
    assert_equal [ 640, 480 ], ImageDimension::Header.parse(webp("VP8L", "\x2f".b + [ bits ].pack("V")))
    assert_equal [ 640, 480 ], ImageDimension::Header.parse(webp("VP8X", "\0\0\0\0\x7f\x02\0\xdf\x01\0".b))
  end

  test "WebP 拒绝无效签名 版本 长度 尺寸及无法确认方向的 EXIF" do
    invalid = [
      webp("VP8 ", "\x11\0\0\x9d\x01\x2a".b + [ 640, 480 ].pack("vv")),
      webp("VP8 ", "\x10\0\0bad".b + [ 640, 480 ].pack("vv")),
      webp("VP8L", "\x2f".b + [ 1 << 29 ].pack("V")),
      webp("VP8X", "\0\0\0\0\xa0\x86\x01\0\0\0".b),
      webp("VP8X", "\x08\0\0\0\x7f\x02\0\xdf\x01\0".b),
      webp("VP8X", "\0\0\0\0\0\0\0\0\0".b),
      "RIFF\0\0\0\0WEBPVP8X".b
    ]
    invalid.each { |bytes| assert_nil ImageDimension::Header.parse(bytes) }
  end

  test "所有识别头部的截断都返回未知" do
    [ png(640, 480), "GIF89a".b + [ 320, 600, 0, 0, 0 ].pack("vvCCC"), jpeg, webp("VP8X", "\0\0\0\0\x7f\x02\0\xdf\x01\0".b) ].each do |bytes|
      (0...bytes.bytesize).each { |length| assert_nil ImageDimension::Header.parse(bytes.byteslice(0, length)) }
    end
  end

  test "未知 SVG 与任意坏字节返回未知且不改变调用方字符串" do
    [ nil, "", "<svg width='640' height='480'/>", "not an image", "\xff\0\xfe".b ].each do |bytes|
      assert_nil ImageDimension::Header.parse(bytes)
    end
    bytes = png(640, 480).force_encoding(Encoding::UTF_8).freeze
    assert_equal [ 640, 480 ], ImageDimension::Header.parse(bytes)
    assert_equal Encoding::UTF_8, bytes.encoding
  end

  private
    def png(width, height, depth: 8, color: 2, before: "".b)
      header = "IHDR".b + [ width, height, depth, color, 0, 0, 0 ].pack("NNCCCCC")
      "\x89PNG\r\n\x1a\n".b + [ 13 ].pack("N") + header + [ Zlib.crc32(header) ].pack("N") + before + [ 1 ].pack("N") + "IDAT"
    end

    def png_chunk(kind, data)
      [ data.bytesize ].pack("N") + kind.b + data + [ Zlib.crc32(kind.b + data) ].pack("N")
    end

    def jpeg(width: 640, height: 480, marker: 0xc0, before: "".b, after: "".b)
      "\xff\xd8".b + before + frame(width: width, height: height, marker: marker) + after + scan
    end

    def frame(width: 640, height: 480, marker: 0xc0)
      segment(marker, [ 8, height, width, 1, 1, 0x11, 0 ].pack("CnnCCCC"))
    end

    def scan
      segment(0xda, "\x01\x01\0\0\x3f\0".b)
    end

    def segment(marker, body)
      [ 0xff, marker, body.bytesize + 2 ].pack("CCn") + body
    end

    def exif(orientation, endian: :little)
      segment(0xe1, "Exif\0\0".b + tiff(orientation, endian: endian))
    end

    def tiff(orientation, endian: :little)
      if endian == :little
        "II".b + [ 42, 8, 1, 0x112, 3, 1, orientation, 0, 0 ].pack("vVvvvVvvV")
      else
        "MM".b + [ 42, 8, 1, 0x112, 3, 1, orientation, 0, 0 ].pack("nNnnnNnnN")
      end
    end

    def webp(kind, header)
      chunk = kind.b + [ header.bytesize ].pack("V") + header
      chunk << "\0" if header.bytesize.odd?
      "RIFF".b + [ chunk.bytesize + 4 ].pack("V") + "WEBP".b + chunk
    end
end
