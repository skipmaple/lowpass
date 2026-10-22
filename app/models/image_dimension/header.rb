require "zlib"

# 只识别完整的尺寸头，不解码像素，也不承诺验证头部之后的压缩数据。
class ImageDimension::Header
  MAX_DIMENSION = 100_000
  PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b.freeze
  JPEG_FRAMES = [ 0xc0, 0xc1, 0xc2 ].freeze

  def self.parse(bytes)
    return unless bytes.is_a?(String)

    new(bytes.b).parse
  end

  def initialize(bytes)
    @bytes = bytes
  end

  def parse
    dimensions = if @bytes.start_with?(PNG_SIGNATURE)
      png
    elsif @bytes.start_with?("GIF87a", "GIF89a")
      gif
    elsif @bytes.start_with?("\xff\xd8".b)
      jpeg
    elsif @bytes.start_with?("RIFF")
      webp
    end
    if dimensions&.all? { |dimension| dimension.is_a?(Integer) && dimension.between?(1, MAX_DIMENSION) }
      dimensions
    end
  end

  private
    # PNG 5.6 requires eXIf before IDAT. Stop at that boundary, not immediately
    # after IHDR, so a valid image's orientation is established without its pixels.
    def png
      dimensions = png_header
      return unless dimensions

      offset = 33
      orientation = 1
      seen_exif = false
      while offset + 8 <= @bytes.bytesize
        length = @bytes.byteslice(offset, 4).unpack1("N")
        kind = @bytes.byteslice(offset + 4, 4)
        return unless length <= 0x7fff_ffff && kind.match?(/\A[A-Za-z]{2}[A-Z][A-Za-z]\z/)
        return orientation >= 5 ? dimensions.reverse : dimensions if kind == "IDAT"
        return if kind.getbyte(0) & 0x20 == 0 && kind != "PLTE"
        return unless offset + length + 12 <= @bytes.bytesize

        data = @bytes.byteslice(offset + 8, length)
        crc = @bytes.byteslice(offset + 8 + length, 4).unpack1("N")
        return unless Zlib.crc32(kind + data) == crc
        if kind == "eXIf"
          return if seen_exif
          seen_exif = true
          orientation = exif_orientation(data)
          return unless orientation
        end
        offset += length + 12
      end
      nil
    end

    # PNG 11.2.1: IHDR is first, has 13 data bytes and a CRC over type + data.
    def png_header
      return unless @bytes.bytesize >= 33 && @bytes.byteslice(8, 8) == "\0\0\0\rIHDR".b

      header = @bytes.byteslice(12, 17)
      return unless Zlib.crc32(header) == @bytes.byteslice(29, 4).unpack1("N")

      width, height, depth, color, compression, filter, interlace = @bytes.byteslice(16, 13).unpack("NNCCCCC")
      depths = { 0 => [ 1, 2, 4, 8, 16 ], 2 => [ 8, 16 ], 3 => [ 1, 2, 4, 8 ], 4 => [ 8, 16 ], 6 => [ 8, 16 ] }
      if depths[color]&.include?(depth) && compression.zero? && filter.zero? && interlace <= 1
        [ width, height ]
      end
    end

    # GIF89a section 18: the logical screen, not an individual frame, sets the canvas.
    def gif
      @bytes.byteslice(6, 4).unpack("vv") if @bytes.bytesize >= 13
    end

    # T.81 B.2.2/B.2.3. EXIF can follow SOF, so don't return before a complete SOS.
    # Uncommon frame types and EXIF that cannot be reliably interpreted stay unknown.
    def jpeg
      offset = 2
      dimensions = nil
      orientation = 1
      seen_exif = false

      while offset < @bytes.bytesize
        return unless @bytes.getbyte(offset) == 0xff
        offset += 1
        offset += 1 while @bytes.getbyte(offset) == 0xff
        marker = @bytes.getbyte(offset)
        offset += 1
        return unless marker && @bytes.bytesize >= offset + 2

        length = @bytes.byteslice(offset, 2).unpack1("n")
        return unless length >= 2 && offset + length <= @bytes.bytesize
        data = @bytes.byteslice(offset + 2, length - 2)

        if JPEG_FRAMES.include?(marker)
          return if dimensions
          dimensions = jpeg_frame(data)
          return unless dimensions
        elsif marker == 0xe1 && data.start_with?("Exif\0\0".b)
          return if seen_exif
          seen_exif = true
          orientation = exif_orientation(data.byteslice(6..))
          return unless orientation
        elsif marker == 0xda
          components = data.getbyte(0)
          return unless dimensions && components&.between?(1, 4) && data.bytesize == 4 + components * 2
          return orientation >= 5 ? dimensions.reverse : dimensions
        elsif !([ 0xc4, 0xcc, 0xdb, 0xdd, 0xfe ].include?(marker) || marker.between?(0xe0, 0xef))
          return
        end
        offset += length
      end
      nil
    end

    def jpeg_frame(data)
      return unless data.bytesize >= 6

      precision, height, width, components = data.unpack("CnnC")
      if [ 8, 12 ].include?(precision) && components.between?(1, 4) && data.bytesize == 6 + 3 * components
        [ width, height ]
      end
    end

    # CIPA Exif: Orientation (0x0112) is a single SHORT in the 0th TIFF IFD.
    def exif_orientation(tiff)
      return unless tiff.bytesize >= 8

      short, long = case tiff.byteslice(0, 2)
      when "II" then [ "v", "V" ]
      when "MM" then [ "n", "N" ]
      else return
      end
      return unless tiff.byteslice(2, 2).unpack1(short) == 42
      offset = tiff.byteslice(4, 4).unpack1(long)
      return unless offset >= 8 && offset + 2 <= tiff.bytesize
      count = tiff.byteslice(offset, 2).unpack1(short)
      return unless offset + 2 + count * 12 + 4 <= tiff.bytesize

      orientation = 1
      seen_orientation = false
      count.times do |index|
        entry = tiff.byteslice(offset + 2 + index * 12, 12)
        if entry.byteslice(0, 2).unpack1(short) == 0x112
          return if seen_orientation || entry.byteslice(2, 2).unpack1(short) != 3 || entry.byteslice(4, 4).unpack1(long) != 1
          seen_orientation = true
          orientation = entry.byteslice(8, 2).unpack1(short)
          return unless orientation.between?(1, 8)
        end
      end
      orientation
    end

    # Google WebP container and VP8/VP8L bitstream specifications.
    def webp
      return unless @bytes.bytesize >= 20 && @bytes.byteslice(8, 4) == "WEBP"

      size = @bytes.byteslice(4, 4).unpack1("V")
      length = @bytes.byteslice(16, 4).unpack1("V")
      return unless size.even? && size >= 12 + length + length % 2

      case @bytes.byteslice(12, 4)
      when "VP8 " then webp_lossy(length)
      when "VP8L" then webp_lossless(length)
      when "VP8X" then webp_extended(length)
      end
    end

    def webp_lossy(length)
      return unless length >= 10 && @bytes.bytesize >= 30
      tag = @bytes.byteslice(20, 3).unpack1("C")
      return unless tag & 1 == 0 && (tag >> 1) & 7 <= 3 && tag & 0x10 != 0 && @bytes.byteslice(23, 3) == "\x9d\x01\x2a".b

      width, height = @bytes.byteslice(26, 4).unpack("vv")
      [ width, height ] if width < 0x4000 && height < 0x4000
    end

    def webp_lossless(length)
      return unless length >= 5 && @bytes.bytesize >= 25 && @bytes.getbyte(20) == 0x2f

      bits = @bytes.byteslice(21, 4).unpack1("V")
      [ (bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1 ] if bits >> 29 == 0
    end

    def webp_extended(length)
      return unless length == 10 && @bytes.bytesize >= 30
      flags = @bytes.getbyte(20)
      # EXIF is after image data in WebP; a prefix cannot safely establish its orientation.
      return unless flags & 0xc9 == 0 && @bytes.byteslice(21, 3) == "\0\0\0".b

      width = @bytes.byteslice(24, 3).unpack("C3").each_with_index.sum { |byte, index| byte << (index * 8) } + 1
      height = @bytes.byteslice(27, 3).unpack("C3").each_with_index.sum { |byte, index| byte << (index * 8) } + 1
      [ width, height ] if width * height <= 0xffff_ffff
    end
end
