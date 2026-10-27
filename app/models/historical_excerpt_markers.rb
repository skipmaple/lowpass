require "digest"
require "json"
require "set"

# 仅恢复已独立核对的源站省略提示；任何身份或正文变化都沿用原显示，不写记录。
class HistoricalExcerptMarkers
  VERIFIED = %w[
    83e2fc081c868c2c9ad11d72b40a877dd1608c58dc46ca552bb91a6bf61e02b1
    b47043583464957759a88734844a938d7e320bb695c5dbd4287b1aa1885ede2b
    2cf98c3efe221b1c9e975e5a7baef0f173a00d4cfe2a545c9667aaeb0dfa4857
    5ffde90c5a7ee8b1df42d214c5435666f9fa058599051c761a6f3c263bca3377
    87a4fb56b905aa2503a36bf678f1eebfea4ec39cf74a0230d7fbe4790392c8b2
    9670be330b0376526de3be8b650f2fe5a8ac95d3594a7ac35b16d47e8774ae43
    15fc452514893ee3f4fcc0f1dceb9a4ed59b1a47867b0d627bb060e02f4cdd95
  ].freeze

  def self.current
    @current ||= new(fingerprints: VERIFIED)
  end

  def initialize(fingerprints:)
    @fingerprints = fingerprints.to_set
  end

  def summary_for(item:, issue:)
    return unless issue.kind == "daily" && issue.state == "published" && item.issue_id == issue.id
    return unless item.summary.is_a?(String) && item.summary.valid_encoding? && item.summary.present?

    identity = [ issue.period_key, issue.id, item.source_id, item.id, item.rank, item.title, item.url, item.summary ]
    return unless identity.grep(String).all?(&:valid_encoding?)
    return unless @fingerprints.include?(Digest::SHA256.hexdigest(JSON.generate(identity)))

    "#{item.summary} …"
  end
end
