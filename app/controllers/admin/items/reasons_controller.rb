# 单条重生成（R-9.6，设计 C6）：读者页上管理员点，同步调一次模型（最多 20 秒 × 3 次），回到那一期
class Admin::Items::ReasonsController < Admin::BaseController
  def create
    item = Item.joins(:issue).where(issues: { kind: "daily" }).find(params[:item_id])
    back = daily_issue_path(item.issue.period_key)
    return redirect_back_or_to(back, alert: "未配置模型供应商") unless Reasons::Provider.configured?

    if Reasons::Generator.generate_item!(item)
      Audit.record("item.regenerate_reason", "Item##{item.id}")
      redirect_back_or_to back, notice: "已重生成"
    else
      # 账本按 created_at 排到毫秒仍可能同时刻（三次重试在同一个事务里连着写），id 是 UUIDv7，做次序的兜底
      reason = ModelCall.where(item: item).order(:created_at, :id).last&.error_summary.presence || "输出不合规"
      redirect_back_or_to back, alert: "重生成失败：#{reason}"
    end
  rescue Reasons::Provider::Rejected => e
    redirect_back_or_to back, alert: "重生成失败：#{e.message}"
  end
end
