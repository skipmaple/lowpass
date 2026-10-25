module Translations::Parser
  LIMITS = { "title" => 300, "summary" => 500 }.freeze
  Invalid = Class.new(StandardError)
  Result = Data.define(:decision, :text)

  def self.parse(text, field:)
    limit = LIMITS[field]
    raise Invalid, "不支持的译文字段" unless limit

    value = JSON.parse(text.to_s)
    raise Invalid, "不是完整对象" unless value.is_a?(Hash)

    case value["decision"]
    when "unchanged"
      raise Invalid, "保留原文不得夹带其他字段" unless value.keys == [ "decision" ]

      Result.new(decision: "unchanged", text: nil)
    when "translated"
      raise Invalid, "译文对象字段不合规" unless value.keys.sort == %w[ decision text ] && value["text"].is_a?(String)

      translated = value["text"].strip.gsub(/\s+/, " ")
      raise Invalid, "译文不合规" unless translated.match?(/\p{Han}/) && translated.length <= limit

      Result.new(decision: "translated", text: translated)
    else
      raise Invalid, "未知翻译结果"
    end
  rescue JSON::ParserError
    raise Invalid, "不是完整 JSON"
  end
end
