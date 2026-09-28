require "net/http"

# 上传到 S3 兼容的对象存储（设计 §2.4）：PutObject 加 AWS Signature V4。地址由运维在环境里配，是可信输入，
# 与告警 webhook、模型端点一样不经 surfguard；只接受 https（本机 http 给演练用，Backup::Config 已挡）；不跟重定向。
# Content-MD5 与 x-amz-content-sha256 都按文件实际内容算，存储端据此校验上传是否完整；请求体从文件流式读。
# 5xx 与网络错误是暂时性（job 再试），其余非 2xx 是终态——403 / 429 不追加请求（仓库不变量）
module Backup::Storage
  OPEN_TIMEOUT = 10
  WRITE_TIMEOUT = 300
  READ_TIMEOUT = 60
  ERROR_BYTES = 2048

  class << self
    def put(name, path)
      uri = URI("#{Backup::Config.bucket_url}/#{name}")
      headers = { "content-type" => "application/octet-stream", "content-md5" => Digest::MD5.file(path).base64digest,
                  "x-amz-content-sha256" => Digest::SHA256.file(path).hexdigest }
      headers.merge!(signer.sign_request(http_method: "PUT", url: uri.to_s, headers: headers).headers)
      request = Net::HTTP::Put.new(uri, headers.merge("content-length" => File.size(path).to_s, "user-agent" => Adapters::Http::USER_AGENT))
      File.open(path, "rb") do |file|
        request.body_stream = file
        response = http(uri).request(request)
        raise failure(response) unless response.is_a?(Net::HTTPSuccess)
      end
    rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise Backup::Transient, "上传没有完成：#{e.class}: #{e.message}"
    end

    private
      # S3 的做法：路径不再转义、不做规整（对象名只有字母数字、点、连字符，两种做法其实一样）
      def signer
        Aws::Sigv4::Signer.new(service: "s3", region: Backup::Config.region, access_key_id: Backup::Config.access_key_id,
                               secret_access_key: Backup::Config.secret_access_key, uri_escape_path: false, normalize_path: false)
      end

      # Net::HTTP 默认会对 PUT 这种幂等请求自己再发一次：关掉，重试只在 BackupJob 一处
      def http(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.is_a?(URI::HTTPS)
          http.open_timeout = OPEN_TIMEOUT
          http.write_timeout = WRITE_TIMEOUT
          http.read_timeout = READ_TIMEOUT
          http.max_retries = 0
        end
      end

      # 存储端的错误是一段 XML，<Code> 里是 AccessDenied、SignatureDoesNotMatch、InvalidDigest 这样的错误码
      def failure(response)
        body = response.body.to_s.b[0, ERROR_BYTES].force_encoding(Encoding::UTF_8).scrub
        code = body[%r{<Code>([^<]{1,64})</Code>}, 1]
        message = "上传失败（#{response.code}）#{"：#{code}" if code}"
        response.is_a?(Net::HTTPServerError) ? Backup::Transient.new(message) : Backup::Error.new(message)
      end
  end
end
