require "test_helper"

class ProbeImageDimensionJobTest < ActiveJob::TestCase
  test "403 与 429 只记缓存退避，不追加 Active Job 重试" do
    travel_to Time.zone.parse("2026-10-22 12:00") do
      [ 403, 429 ].each do |status|
        url = "https://example.com/#{status}.png"
        record = ImageDimension.create!(url: url, url_hash: Digest::SHA256.hexdigest(url), queued_at: Time.current)
        Adapters::Http.stubs(:get_prefix).raises(Adapters::Http::Blocked, status.to_s)

        assert_no_enqueued_jobs(only: ProbeImageDimensionJob) { ProbeImageDimensionJob.perform_now(record) }

        assert_equal 1.day.from_now, record.reload.retry_at
        assert_nil record.queued_at
        assert_nil record.width
      end
    end
  end
end
