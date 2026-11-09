# 刊物列表里的理由任务状态。队列是否完成与内容是否生成成功是两件事：
# Generator 会记下失败并继续下一条，所以结果还要核对真实写回与调用账本。
# 只读已有队列和业务记录，不另建一份容易与 worker 失步的运行状态。
class Reasons::Progress
  def self.for_issues(issues)
    return {} unless persistent_queue? && issues.any?

    by_key = issues.index_by { |issue| GenerateReasonsJob.new(issue).concurrency_key }
    jobs = SolidQueue::Job.where(class_name: "GenerateReasonsJob", concurrency_key: by_key.keys)
                         .where("finished_at IS NULL OR finished_at >= ?", 1.day.ago)
                         .includes(:claimed_execution, :failed_execution).order(created_at: :desc)
    jobs.group_by(&:concurrency_key).to_h do |key, runs|
      # 已有重复排队时，优先呈现执行中的那一趟，不让后来的占位盖住进度。
      job = runs.find(&:claimed?) || runs.find { |run| !run.finished? && !run.failed? } || runs.first
      issue = by_key.fetch(key)
      [ issue.id, new(issue, job).to_h ]
    end
  end

  def self.active?(issue)
    persistent_queue? && SolidQueue::Job.where(class_name: "GenerateReasonsJob", concurrency_key: GenerateReasonsJob.new(issue).concurrency_key,
                                              finished_at: nil).where.missing(:failed_execution).exists?
  end

  def self.persistent_queue?
    GenerateReasonsJob.queue_adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter)
  end
  private_class_method :persistent_queue?

  def initialize(issue, job)
    @issue = issue
    @job = job
  end

  def to_h
    items = @issue.items.visible.daily
    period = @job.created_at..(@job.finished_at || Time.current)
    updated = items.where(reason_generated_at: period).where.not(reason: nil)
    assessed = items.joins(:reason_abstention).where(reason_abstentions: { assessed_at: period })
    updated_ids = updated.pluck(:id)
    assessed_ids = assessed.pluck(:id)
    processed_ids = updated_ids | assessed_ids
    missing = items.pending_reasons.count
    detail = [ "已更新 #{updated_ids.size} 条", ("资料不足 #{assessed_ids.size} 条" if assessed_ids.any?), "仍缺 #{missing} 条" ].compact.join(" · ")

    if @job.failed?
      result("failed", "生成任务中断", detail, "任务中断，请在任务队列查看记录后重试。")
    elsif !@job.finished?
      if @job.claimed?
        result("running", "正在生成理由", detail)
      else
        result("queued", "理由已排队", "等待后台处理 · 仍缺 #{missing} 条")
      end
    else
      only_missing = @job.arguments.fetch("arguments", [])[1] != false
      complete = only_missing ? missing.zero? : processed_ids.size == items.count
      if complete
        result("completed", "理由生成完成", detail)
      else
        error = ModelCall.where(issue: @issue, purpose: "reason", created_at: period)
                         .where.not(item_id: processed_ids).where.not(error_summary: nil).order(created_at: :desc, id: :desc).pick(:error_summary)
        error ||= if !Reasons.ready? then Reasons.unready_label
        elsif Reasons::Budget.exhausted? then "本月模型费用已达上限"
        else "部分条目未生成新理由，已有内容已保留。"
        end
        result(processed_ids.any? ? "partial" : "failed", processed_ids.any? ? "部分理由未生成" : "本次未生成理由", detail, error)
      end
    end
  end

  private
    def result(status, label, detail, error = nil)
      { status: status, active: %w[ queued running ].include?(status), label: label, detail: detail, error: error }
    end
end
