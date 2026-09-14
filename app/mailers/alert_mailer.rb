# 告警邮件：主题是正文首行加来源，正文就是 Alerts::Message 的纯文本，不用模板
class AlertMailer < ApplicationMailer
  def event(event, phase)
    mail(to: Alerts::Config.email_to, from: Alerts::Config.email_from, subject: Alerts::Message.subject(event, phase),
         body: Alerts::Message.text(event, phase), content_type: "text/plain")
  end
end
