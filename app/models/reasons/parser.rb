# 模型输出 → 理由、标签与译文（R-9.3、设计 C4、D25）：先当整段 JSON 解析，不行就取第一个 {…}（不支持 response_format 的端点会夹杂文字）；
# 20 到 60 字，超长截断、过短判失败；领域名必须是画像里启用的名字，否则判失败（调用方重试）。
# 译文（标题 title_zh、说明 summary_zh）是顺带的：缺了、不含汉字、超过上限都只当没有，不判失败——不能为了译文把理由也重试掉
module Reasons::Parser
  MIN = 20
  MAX = 60
  TITLE_MAX = 300
  SUMMARY_MAX = 500
  Invalid = Class.new(StandardError)
  Result = Data.define(:reason, :interest_tag, :title_zh, :summary_zh)

  class << self
    def parse(text, allowed_names)
      json = extract(text.to_s)
      reason = json["reason"].to_s.strip.gsub(/\s+/, " ")
      tag = json["interest_tag"].to_s.strip
      raise Invalid, "理由太短（#{reason.length} 字）" if reason.length < MIN
      raise Invalid, "缺领域名" unless allowed_names.include?(tag)
      Result.new(reason: reason[0, MAX], interest_tag: tag,
                 title_zh: translation(json["title_zh"], TITLE_MAX), summary_zh: translation(json["summary_zh"], SUMMARY_MAX))
    end

    private
      def extract(text)
        json = parse_json(text) || parse_json(text[/\{.*\}/m].to_s)
        raise Invalid, "不是 JSON" unless json.is_a?(Hash)
        json
      end

      def parse_json(candidate)
        JSON.parse(candidate)
      rescue JSON::ParserError
        nil
      end

      # 不截断：半句译文比没有更误导
      def translation(value, limit)
        return unless value.is_a?(String)

        text = value.strip.gsub(/\s+/, " ")
        text if text.match?(/\p{Han}/) && text.length <= limit
      end
  end
end
