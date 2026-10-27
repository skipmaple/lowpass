require "digest"
require "json"

# 仅在固定原文与已发布条目完整匹配时，为第 415 期经核对的条目恢复正文链接。
class HistoricalWeeklyReferenceLinks
  ENTRIES = {
    "54c40ff0773a5f3118116d8024210f9eaa2f42842e2311f789a12da827bf976d" => [
      [ 0, 16, 19, "https://www.instagram.com/p/DTbQ9FUDea-/" ]
    ].freeze,
    "59ef50f3a75cc6d9532a63c0a709885190cdbc6c831a23f2b067a6c83acb5987" => [
      [ 6, 30, 40, "https://quesma.com/blog/invisible-cities-one-shot/" ],
      [ 7, 25, 28, "https://p.migdal.pl/invisible-cities-opus-5.5/" ],
      [ 7, 29, 31, "https://github.com/stared/invisible-cities-opus-5.5" ],
      [ 7, 51, 54, "https://p.migdal.pl/invisible-cities-astra/" ],
      [ 7, 55, 57, "https://github.com/stared/invisible-cities-astra" ]
    ].freeze,
    "77ff8edce5dc26cc989ffdbd167b98b58511e9e185de6cab325ffa30f593ed8b" => [
      [ 3, 3, 6, "https://github.com/billpwchan/sakura-fantasy" ],
      [ 3, 56, 62, "https://github.com/ruanyf/weekly/issues/12067" ],
      [ 4, 3, 7, "https://github.com/billpwchan/neon-zenith" ],
      [ 4, 31, 37, "https://github.com/ruanyf/weekly/issues/12103" ]
    ].freeze,
    "2710cd8239bf7b3ab0d4be432ed943d03df8034caeae36a526cc3120889af483" => [
      [ 0, 22, 24, "https://lightbulbcomputer.com/" ]
    ].freeze,
    "504e2e68c8507ec11b6a1c775d4226b397cd2c29a82d89af58f9193eb4467618" => [
      [ 0, 8, 10, "https://deno.com/blog/cloudflare" ],
      [ 5, 19, 21, "https://news.ycombinator.com/item?id=50019911#50023277" ]
    ].freeze,
    "aaec75317d4340476e084786f8fc11be750a4f9a757c2403c4df9974a8762012" => [
      [ 0, 88, 100, "https://github.com/ruanyf/weekly/issues/12134" ]
    ].freeze,
    "0ed70b4feb5dfc1360274415abd65948f9f44c6564efbe54df10b0be621bed36" => [
      [ 1, 30, 32, "https://news.ycombinator.com/item?id=50062172" ]
    ].freeze,
    "5fc8f0fcd4e5450cfcf07414b51d7d7700e5ebe573b2c44547caa2e2cff48f71" => [
      [ 0, 68, 75, "https://github.com/ruanyf/weekly/issues/12097" ]
    ].freeze,
    "02b507b73ed927db1851fa3439a080bd3ad44af0639114dee2d1a8c1f488d7ca" => [
      [ 0, 34, 47, "https://github.com/ruanyf/weekly/issues/12100" ]
    ].freeze,
    "b8edc3f5ddf89bfdb6b62aea35fc6607eaad44303eb09a4b4eaeb93fa01f583b" => [
      [ 0, 57, 65, "https://github.com/ruanyf/weekly/issues/12099" ]
    ].freeze,
    "3c521a9a972fc746f47e0a7596e0218fb8d922d40fca3ed5e50dc0caa03a8827" => [
      [ 0, 61, 69, "https://github.com/ruanyf/weekly/issues/12123" ]
    ].freeze,
    "e37b6b594fc1d59b9db495d4da860f9478d789523993c7ddbf96641efc4f3071" => [
      [ 0, 24, 36, "https://github.com/ruanyf/weekly/issues/12130" ]
    ].freeze,
    "5cfaf2c65d5cd739e073b6e355c2c3f4f08aee35addabd76aa5249a97648178e" => [
      [ 0, 41, 50, "https://github.com/ruanyf/weekly/issues/12129" ]
    ].freeze,
    "afddea59e96f80f5c26e10c7c28a750336ae25da131220f56b47fdd32b34856f" => [
      [ 0, 59, 65, "https://github.com/ruanyf/weekly/issues/12157" ]
    ].freeze,
    "cf6950092dffb5cf39a579d8835691d801f6fb1f1a0be688c858bc43dfc76f70" => [
      [ 0, 36, 46, "https://github.com/ruanyf/weekly/issues/12141" ]
    ].freeze,
    "613ab6ada695b94cd10bcf0a006aa2f27f8b74d44b7b0c0126f9eb99feaea53a" => [
      [ 0, 66, 77, "https://github.com/ruanyf/weekly/issues/12194" ]
    ].freeze,
    "caaa9c2614654853e4cae5d148d2980317a6341d14d5536204286a07e00c4266" => [
      [ 0, 88, 102, "https://github.com/ruanyf/weekly/issues/12340" ]
    ].freeze,
    "1538dfa5c5c3b7d41333f657f34f36ec61900eb617f9861c1676946415b83aa1" => [
      [ 0, 77, 87, "https://github.com/ruanyf/weekly/issues/12364" ]
    ].freeze,
    "65d9fa83c0dce8006d24363bac9cb23288871804678cb9596cdd094af5a1da38" => [
      [ 0, 83, 92, "https://github.com/ruanyf/weekly/issues/12158" ]
    ].freeze,
    "c58cd0905c6a2f9607d94482880dae5c9f2e8e4301522ca33be1f43ee895d207" => [
      [ 0, 69, 82, "https://github.com/ruanyf/weekly/issues/12240" ]
    ].freeze,
    "237b16390d6d8a6d555d161c0f5af96138f879120032b5cf8621548ca284fda8" => [
      [ 0, 52, 62, "https://github.com/ruanyf/weekly/issues/12233" ]
    ].freeze,
    "636f7b49ab0281f71d0e4d560782538c10808541aa445e74cb3fab6b65103636" => [
      [ 0, 36, 43, "https://github.com/ruanyf/weekly/issues/12316" ]
    ].freeze,
    "f70e8a9ef55b9faf7ebdd12b224d8ea3172fa7b57ee3bc2e70864204d5f7eaa5" => [
      [ 0, 55, 66, "https://github.com/ruanyf/weekly/issues/12324" ]
    ].freeze,
    "e068b675c310f3096c120f4fcc5d898ddae55fb0f139a3c700d10fff50523208" => [
      [ 1, 3, 13, "https://ken.arneson.name/2015/11/the-value-of-not-getting-to-the-point/" ]
    ].freeze,
    "166540fc84db72d6852bd181b0ca44379cc8f85ddde5da6587d962e5f8f4221e" => [
      [ 1, 3, 6, "https://www.kocpc.com.tw/archives/671794" ]
    ].freeze,
    "67458c57eb65a549b8aa5ed6bc7a72a47a3c3fe27f51ed8d9c8d8ee5f1a882e3" => [
      [ 1, 3, 12, "https://antonz.org/write-code/" ]
    ].freeze,
    "2db0bb03c9b1d381b0098f474aec37ee09c415f7711013597fa7df1fb2163486" => [
      [ 1, 2, 13, "https://www.spinellis.gr/blog/20261008/?li261008" ]
    ].freeze
  }.freeze

  def self.current
    @current ||= new(entries: ENTRIES)
  end

  def initialize(entries:)
    @entries = entries
  end

  def links_for(item:, issue:, source:)
    return unless issue.kind == "weekly" && issue.state == "published" && source.adapter == "ruanyf_weekly"
    return unless item.issue_id == issue.id && item.source_id == source.id && item.meta.is_a?(Hash)
    return if item.meta.key?("reference_links")
    content = item.content
    images = item.meta["image_urls"] || []
    return unless content.is_a?(String) && content.present? && content.valid_encoding? && content.length < SummaryCleaner::CONTENT_LIMIT
    return unless images.is_a?(Array) && images.all? { |image| image.is_a?(String) }

    identity = [ issue.period_key, source.adapter, item.meta["issue_no"], issue.id, source.id, item.id, item.rank, item.title,
      item.url, item.section, Digest::SHA256.hexdigest(content), Digest::SHA256.hexdigest(JSON.generate(images)) ]
    links = @entries[Digest::SHA256.hexdigest(JSON.generate(identity))]
    return unless links.is_a?(Array) && links.size.between?(1, 128)
    paragraphs = content.split("\n", -1)
    return unless links.each_with_index.all? do |link, i|
      next false unless link.is_a?(Array) && link.size == 4 && link.first(3).all? { |n| n.is_a?(Integer) }
      paragraph, start, finish, href = link
      next false unless paragraph.between?(0, paragraphs.size - 1) && start >= 0 && start < finish && finish <= paragraphs[paragraph].length
      next false unless href.is_a?(String) && Adapters::RuanyfWeekly::ReferenceLinks.absolute(href, item.meta["issue_no"]) == href
      i.zero? || paragraph > links[i - 1][0] || (paragraph == links[i - 1][0] && start >= links[i - 1][2])
    end
    links.map { |paragraph, start, finish, href| [ paragraph, start, finish, href.dup ] }
  rescue JSON::GeneratorError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    nil
  end
end
