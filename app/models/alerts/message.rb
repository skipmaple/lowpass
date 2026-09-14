# 告警正文（R-7.2、设计 §6）：事件名、来源、期、摘要、后台链接；纯文本，邮件与 webhook 同一份（B13）
module Alerts::Message
  class << self
    def headline(event, phase) = "[lowpass] #{phase == "recovery" ? "已恢复" : event.level_label} · #{event.kind_label}"

    def subject(event, phase) = [ headline(event, phase), event.source&.name ].compact.join(" · ")

    def url(event) = Alerts::Config.base_url.chomp("/") + event.url_path

    def text(event, phase)
      lines = [ headline(event, phase) ]
      lines << "来源：#{event.source.name}" if event.source
      lines << "期：#{event.issue.period_key}" if event.issue
      lines << "摘要：#{event.summary}" if phase == "alert" && event.summary.present?
      lines << url(event)
      lines.join("\n")
    end
  end
end
