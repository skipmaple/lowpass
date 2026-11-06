class GenerateItemReasonJob < ApplicationJob
  queue_as :default
  retry_on ModelRequests::Busy, wait: 5.seconds, attempts: :unlimited

  def perform(item, operation)
    return unless ModelRequests.valid_operation?(operation)
    return if item.hidden? || item.issue.kind != "daily"

    Reasons::Generator.generate_item!(item, operation: operation)
  end
end
