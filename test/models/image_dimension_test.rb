require "test_helper"

class ImageDimensionTest < ActiveSupport::TestCase
  test "只读已确认尺寸，刷新期到后仍保留占位，不为缺失 URL 写记录或入队" do
    assert Object.const_defined?(:ImageDimension), "需要独立的天然尺寸缓存"

    travel_to Time.zone.parse("2026-10-22 12:00") do
      fresh = dimension("https://example.com/fresh.png", width: 640, height: 480, confirmed_at: 29.days.ago)
      expired = dimension("https://example.com/expired.png", width: 100, height: 200, confirmed_at: 30.days.ago)
      pending = dimension("https://example.com/pending.png")
      urls = [ fresh.url, expired.url, pending.url, "https://example.com/missing.png" ]

      assert_no_difference("ImageDimension.count") do
        assert_no_enqueued_jobs do
          assert_equal({ fresh.url => { width: 640, height: 480 }, expired.url => { width: 100, height: 200 } }, ImageDimension.for_urls(urls))
        end
      end
    end
  end

  test "登记完整 URL 并去重，每次最多入队十张，不在入队时请求图片" do
    urls = (1..12).map { |i| "https://example.com/image.png?size=#{i}#full" }
    invalid = [ nil, 7, "", "javascript:alert(1)", "file:///tmp/a", "https://", "https://user:pass@example.com/a", "https://example.com/" + "a" * 2048 ]
    Adapters::Http.expects(:get).never

    assert_enqueued_jobs 10, only: ProbeImageDimensionJob do
      assert_equal 10, ImageDimension.enqueue_for(urls + urls + invalid)
    end
    assert_equal 12, ImageDimension.count
    assert_equal urls.sort, ImageDimension.pluck(:url).sort

    assert_enqueued_jobs 2, only: ProbeImageDimensionJob do
      assert_equal 2, ImageDimension.enqueue_for(urls)
    end
    assert_no_enqueued_jobs(only: ProbeImageDimensionJob) { ImageDimension.enqueue_for(urls) }
    assert_equal Digest::SHA256.hexdigest(urls.first), ImageDimension.find_by!(url: urls.first).url_hash
  end

  test "有效缓存不入队，三十天后刷新但仍然可读尺寸" do
    travel_to Time.zone.parse("2026-10-22 12:00") do
      fresh = dimension("https://example.com/fresh.png", width: 640, height: 480, confirmed_at: 29.days.ago)
      expired = dimension("https://example.com/expired.png", width: 100, height: 200, confirmed_at: 30.days.ago)

      assert_enqueued_with(job: ProbeImageDimensionJob, args: [ expired ]) { ImageDimension.enqueue_for([ fresh.url, expired.url ]) }
      assert_equal({ fresh.url => { width: 640, height: 480 }, expired.url => { width: 100, height: 200 } }, ImageDimension.for_urls([ fresh.url, expired.url ]))
    end
  end

  test "十分钟内租约阻止重复入队，遗失任务在租约到期后补跑" do
    now = Time.zone.parse("2026-10-22 12:00")
    url = "https://example.com/lease.png"
    ImageDimension.enqueue_for([ url ], now: now)

    assert_no_enqueued_jobs(only: ProbeImageDimensionJob) { ImageDimension.enqueue_for([ url ], now: now + 9.minutes) }
    assert_enqueued_jobs 1, only: ProbeImageDimensionJob do
      ImageDimension.enqueue_for([ url ], now: now + 10.minutes)
    end
  end

  test "入队失败释放租约，下一次 tick 能补跑" do
    url = "https://example.com/requeue.png"
    ProbeImageDimensionJob.stubs(:perform_later).returns(false)
    assert_equal 0, ImageDimension.enqueue_for([ url ])
    assert_nil ImageDimension.find_by!(url: url).queued_at
    ProbeImageDimensionJob.unstub(:perform_later)

    assert_enqueued_jobs 1, only: ProbeImageDimensionJob do
      assert_equal 1, ImageDimension.enqueue_for([ url ])
    end
  end

  test "入队发生异常同样释放租约，不影响调用方" do
    url = "https://example.com/requeue-error.png"
    ProbeImageDimensionJob.stubs(:perform_later).raises(ActiveJob::EnqueueError, "queue unavailable")
    assert_equal 0, ImageDimension.enqueue_for([ url ])
    assert_nil ImageDimension.find_by!(url: url).queued_at
  end

  test "先认领后入队，重入调度不会为同一 URL 再排任务" do
    url = "https://example.com/concurrent.png"
    now = Time.zone.parse("2026-10-22 12:00")
    outer_calls = 0
    ProbeImageDimensionJob.stubs(:perform_later).with do |_record|
      outer_calls += 1
      ImageDimension.enqueue_for([ url ], now: now) if outer_calls == 1
      true
    end.returns(true)

    assert_equal 1, ImageDimension.enqueue_for([ url ], now: now)
    assert_equal 1, outer_calls
    assert_equal 1, ImageDimension.count
    assert_equal now, ImageDimension.sole.queued_at
    assert_equal 0, ImageDimension.enqueue_for([ url ], now: now)
  end

  test "缓存读取故障退回未知尺寸" do
    ImageDimension.stubs(:where).raises(ActiveRecord::StatementInvalid, "cache unavailable")
    assert_equal({}, ImageDimension.for_urls([ "https://example.com/a.png" ]))
  end

  test "缓存登记故障不影响调用方" do
    ImageDimension.stubs(:where).raises(ActiveRecord::StatementInvalid, "cache unavailable")
    assert_equal 0, ImageDimension.enqueue_for([ "https://example.com/a.png" ])
  end

  test "已确认尺寸在刷新期限内再次登记只读数据库" do
    record = dimension("https://example.com/no-write.png", width: 640, height: 480, confirmed_at: Time.current)

    assert_no_queries_match(/\A(?:INSERT|UPDATE|DELETE)\b/i) { ImageDimension.enqueue_for([ record.url ]) }
  end

  test "同时选中同一行的竞争者不能释放已经被认领的租约" do
    now = Time.zone.parse("2026-10-22 12:00")
    record = dimension("https://example.com/claimed.png", queued_at: now)

    assert_not record.send(:queue_if_due, now)
    assert_equal now, record.reload.queued_at
  end

  test "入库约束保证尺寸完整、为正且不过大" do
    record = dimension("https://example.com/constraints.png")
    [ { width: 1 }, { width: 1, height: 0, confirmed_at: Time.current },
      { width: 100_001, height: 1, confirmed_at: Time.current },
      { width: 1, height: 1 } ].each do |attributes|
      assert_raises ActiveRecord::StatementInvalid do
        ImageDimension.transaction(requires_new: true) { record.update_columns(attributes) }
      end
    end

    record.reload.update!(width: 100_000, height: 1, confirmed_at: Time.current)
    assert_equal 100_000, record.reload.width
  end

  test "相同完整 URL 只有一行，数据库保证唯一" do
    record = dimension("https://example.com/unique.png")
    duplicate = record.dup
    assert_raises ActiveRecord::RecordNotUnique do
      ImageDimension.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "探测只取有限图片头并缓存天然尺寸三十天" do
    travel_to Time.zone.parse("2026-10-22 12:00") do
      record = dimension("https://example.com/size.png", queued_at: Time.current)
      response = Adapters::Http::Response.new(206, png_header(640, 480), "image/png")
      Adapters::Http.expects(:get_prefix).with(record.url, timeout: 5, max_bytes: 128.kilobytes).once.returns(response)

      record.probe_now

      assert_equal [ 640, 480, Time.current, nil, nil ], record.reload.attributes.values_at("width", "height", "confirmed_at", "retry_at", "queued_at")
      assert_no_enqueued_jobs(only: ProbeImageDimensionJob) { ImageDimension.enqueue_for([ record.url ], now: Time.current + 29.days) }
      assert_enqueued_jobs 1, only: ProbeImageDimensionJob do
        ImageDimension.enqueue_for([ record.url ], now: Time.current + 30.days)
      end
    end
  end

  test "坏图退避一天，重复的探测任务不立即重试" do
    travel_to Time.zone.parse("2026-10-22 12:00") do
      record = dimension("https://example.com/bad.png", queued_at: Time.current)
      response = Adapters::Http::Response.new(206, "not an image", "image/png")
      Adapters::Http.expects(:get_prefix).once.returns(response)

      record.probe_now
      record.probe_now

      assert_equal [ nil, nil, nil, 1.day.from_now, nil ], record.reload.attributes.values_at("width", "height", "confirmed_at", "retry_at", "queued_at")
      assert_no_enqueued_jobs(only: ProbeImageDimensionJob) { ImageDimension.enqueue_for([ record.url ], now: Time.current + 1.day - 1.second) }
      assert_enqueued_jobs 1, only: ProbeImageDimensionJob do
        ImageDimension.enqueue_for([ record.url ], now: Time.current + 1.day)
      end
    end
  end

  test "刷新请求失败保留已确认宽高并退避一天" do
    travel_to Time.zone.parse("2026-10-22 12:00") do
      record = dimension("https://example.com/old.png", width: 320, height: 640, confirmed_at: 31.days.ago, queued_at: Time.current)
      Adapters::Http.expects(:get_prefix).once.raises(Adapters::Http::Blocked, "429")

      assert_no_enqueued_jobs do
        record.probe_now
        record.probe_now
      end

      assert_equal({ record.url => { width: 320, height: 640 } }, ImageDimension.for_urls([ record.url ]))
      assert_equal 1.day.from_now, record.reload.retry_at
      assert_nil record.queued_at
    end
  end

  test "新鲜结果的旧任务直接结束而不再请求" do
    record = dimension("https://example.com/fresh.png", width: 640, height: 480, confirmed_at: Time.current)
    Adapters::Http.expects(:get_prefix).never
    record.probe_now
  end

  test "发现只扫描已发布周刊的可见条目且不改写条目或刊期" do
    weekly = issues(:weekly_w36)
    image = weekly_item(weekly, "weekly", [ "https://example.com/weekly.png" ])
    weekly_item(weekly, "hidden", [ "https://example.com/hidden.png" ], hidden: true)
    weekly_item(issues(:daily_0908), "daily", [ "https://example.com/daily.png" ])
    generating = Issue.weekly.create!(period_key: "2026-W37", state: "generating", generation_started_at: Time.current)
    weekly_item(generating, "generating", [ "https://example.com/generating.png" ])
    before_issue = weekly.reload.attributes
    before_item = image.reload.attributes

    assert_enqueued_jobs 1, only: ProbeImageDimensionJob do
      assert_equal 1, ImageDimension.discover_later(now: Time.current)
    end

    assert_equal [ "https://example.com/weekly.png" ], ImageDimension.pluck(:url)
    assert_equal before_issue, weekly.reload.attributes
    assert_equal before_item, image.reload.attributes
  end

  test "发现最多读取五百个条目的元数据" do
    weekly = issues(:weekly_w36)
    template = items(:hn_one).attributes.except("id").merge("issue_id" => weekly.id, "source_id" => sources(:ruanyf).id)
    rows = 501.times.map do |index|
      template.merge("id" => Lowpass::Uuid.generate, "rank" => index, "url" => "https://example.com/item/#{index}",
        "url_hash" => Digest::SHA256.hexdigest("https://example.com/item/#{index}"),
        "meta" => { "image_urls" => (index < 500 ? [] : [ "https://example.com/outside-limit.png" ]) })
    end
    Item.insert_all!(rows)

    assert_no_enqueued_jobs(only: ProbeImageDimensionJob) do
      ImageDimension.discover_later(now: Time.current)
    end
    assert_equal 0, ImageDimension.count
  end

  test "发现每次最多登记一百个不同 URL 并入队十个任务" do
    urls = (1..101).map { |index| "https://example.com/image/#{index}" }
    weekly_item(issues(:weekly_w36), "many", urls)

    assert_enqueued_jobs 10, only: ProbeImageDimensionJob do
      ImageDimension.discover_later(now: Time.current)
    end
    assert_equal 100, ImageDimension.count
    assert ImageDimension.exists?(url: "https://example.com/image/1")
    assert_not ImageDimension.exists?(url: "https://example.com/image/101")
  end

  test "首批尺寸全部确认后下个 tick 继续登记后续 URL，每轮仍最多新增一百个" do
    now = Time.zone.parse("2026-10-22 12:00")
    urls = (1..201).map { |index| "https://example.com/progress/#{index}" }
    weekly_item(issues(:weekly_w36), "progress", urls)
    ImageDimension.discover_later(now: now)
    ImageDimension.update_all(width: 640, height: 480, confirmed_at: now, queued_at: nil)

    assert_difference("ImageDimension.count", 100) do
      assert_enqueued_jobs 10, only: ProbeImageDimensionJob do
        ImageDimension.discover_later(now: now + 1.minute)
      end
    end
    assert ImageDimension.exists?(url: "https://example.com/progress/101")
    assert_not ImageDimension.exists?(url: "https://example.com/progress/201")

    ImageDimension.where(confirmed_at: nil).update_all(width: 640, height: 480, confirmed_at: now, queued_at: nil)
    assert_difference("ImageDimension.count", 1) do
      assert_enqueued_jobs 1, only: ProbeImageDimensionJob do
        ImageDimension.discover_later(now: now + 2.minutes)
      end
    end
    assert_equal now + 2.minutes, ImageDimension.find_by!(url: "https://example.com/progress/201").queued_at
  end

  test "已登记的后续 URL 到期时仍可入队，不被前一百个新鲜缓存挡住" do
    now = Time.zone.parse("2026-10-22 12:00")
    urls = (1..101).map { |index| "https://example.com/known/#{index}" }
    ImageDimension.enqueue_for(urls, now: now)
    ImageDimension.update_all(width: 640, height: 480, confirmed_at: now, queued_at: nil)
    pending = dimension("https://example.com/known/101")

    assert_no_difference("ImageDimension.count") do
      assert_enqueued_with(job: ProbeImageDimensionJob, args: [ pending ]) { ImageDimension.enqueue_for(urls, now: now) }
    end
  end

  private
    def dimension(url, **attributes)
      ImageDimension.create!(url: url, url_hash: Digest::SHA256.hexdigest(url), **attributes)
    end

    def png_header(width, height)
      ihdr = "IHDR" + [ width, height ].pack("N2") + "\x08\x02\x00\x00\x00".b
      "\x89PNG\r\n\x1a\n".b + [ 13 ].pack("N") + ihdr + [ Zlib.crc32(ihdr) ].pack("N") + [ 1 ].pack("N") + "IDAT"
    end

    def weekly_item(issue, slug, urls, **attributes)
      items(:hn_one).dup.tap do |item|
        item.assign_attributes(issue: issue, source: sources(:ruanyf), url: "https://example.com/#{slug}",
          url_hash: Digest::SHA256.hexdigest("https://example.com/#{slug}"), meta: { image_urls: urls }, **attributes)
        item.save!
      end
    end
end
