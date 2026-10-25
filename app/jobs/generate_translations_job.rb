class GenerateTranslationsJob < ApplicationJob
  queue_as :default
  retry_on ModelRequests::Busy, wait: 5.seconds, attempts: :unlimited

  def perform(issue, payload)
    return unless ModelRequests.valid_operation?(payload.fetch("operation"))

    result = Translations::Generator.generate!(issue, targets: payload.fetch("targets"), operation: payload.fetch("operation"), reassess: payload.fetch("reassess", false))
    Rails.logger.info { "Issue #{issue.period_key} translations #{payload.fetch("operation").fetch("key")}: #{result.to_h}" }
  end
end
