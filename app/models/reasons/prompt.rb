# 提示词（R-9.2）：只给标题、说明、来源与可读的元数据，不抓原文；画像全文来自 InterestArea.profile_text
module Reasons::Prompt
  SYSTEM = <<~TEXT.freeze
    你是一份中文技术刊物的编辑。读者有一份兴趣画像（每行「领域：关键词」）。请为给出的条目写一句推荐理由：
    中文，20 到 60 字，必须点名画像里的一个领域名；相关度不高就直说「相关度中等」或「相关度较低」，不得编造关联。
    只输出 JSON：{"reason": "...", "interest_tag": "<领域名>"}。
  TEXT

  class << self
    def messages(item, profile_text)
      [ { role: "system", content: SYSTEM },
        { role: "user", content: user_content(item, profile_text) } ]
    end

    private
      def user_content(item, profile_text)
        <<~TEXT
          兴趣画像：
          #{profile_text}

          条目：
          标题：#{item.title}
          说明：#{item.summary.presence || "（无）"}
          来源：#{item.source.name}
          元数据：#{meta_line(item.meta)}
        TEXT
      end

      def meta_line(meta)
        parts = []
        parts << "分数 #{meta["score"]}" if meta["score"]
        parts << "评论 #{meta["comments"]}" if meta["comments"]
        parts << "star #{meta["stars"]}" if meta["stars"]
        parts << "语言 #{meta["language"]}" if meta["language"].present?
        parts.any? ? parts.join(" · ") : "（无）"
      end
  end
end
