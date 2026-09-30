module Adapters
  class Http
    # net-http 逐行读状态行、响应头与 chunked 的分块长度行（BufferedIO#readuntil），正文的 max_bytes 管不到这些：
    # 恶意源站回一个没完没了的头，一行多长、多少行都照单全收，进程就被撑爆。连上以后给这条连接
    # 逐行读的总量设个上限，正常的响应头加分块长度行远远用不完。只挂在自己建的连接上，不改全局的 Net::HTTP
    module CappedLines
      MAX_BYTES = 256.kilobytes

      module Reader
        def readuntil(terminator, ignore_eof = false, limit: nil)
          @line_bytes ||= 0
          budget = [ limit, MAX_BYTES - @line_bytes ].compact.min
          raise Net::ReadLimitExceeded, "exceeded the #{MAX_BYTES} byte line budget" unless budget.positive?

          super(terminator, ignore_eof, limit: budget).tap { |line| @line_bytes += line.bytesize }
        end
      end

      private
        def connect
          super
          @socket.extend(Reader)
        end
    end
  end
end
