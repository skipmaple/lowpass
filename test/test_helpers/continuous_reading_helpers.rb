module ContinuousReadingHelpers
  private
    def prepare_continuous_issue
      issue = issues(:daily_0908)
      [ sources(:hn), sources(:github), sources(:hackaday) ].each do |source|
        10.times do |index|
          url = "https://example.com/continuous/#{source.id}/#{index}"
          Item.create!(issue: issue, source: source, title: "#{source == sources(:github) ? 'GitHub' : source.name} story #{index + 1}", url: url, url_hash: Digest::SHA256.hexdigest(url), rank: index + 2, summary: "A readable description for this technical article. " * 4, reason: "这是一条用于验证连续阅读衔接的推荐理由。", fetched_at: Time.current)
        end
      end
      issue.update!(source_states: issue.source_states.transform_values { "ok" })
    end
end
