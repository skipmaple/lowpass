module Translations::Preview
  Invalid = Class.new(StandardError)
  PURPOSE = "independent-translations"

  def self.issue(issue, user:, reassess: false)
    targets = Translations.targets(issue, reassess: reassess)
    payload = { "user_id" => user.id, "issue_id" => issue.id, "reassess" => reassess,
      "operation" => ModelRequests.operation, "targets" => targets }
    { token: verifier.generate(payload, purpose: PURPOSE, expires_in: 15.minutes), target_count: targets.size }
  end

  def self.verify(token, issue:, user:)
    payload = verifier.verified(token.to_s, purpose: PURPOSE)
    unless payload && payload["user_id"] == user.id && payload["issue_id"] == issue.id && ModelRequests.valid_operation?(payload["operation"])
      raise Invalid, "预览已失效，请重新打开确认"
    end
    payload
  end

  def self.verifier = Rails.application.message_verifier(PURPOSE)
end
