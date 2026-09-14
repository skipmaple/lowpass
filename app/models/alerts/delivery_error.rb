# 渠道发不出去：DeliverAlertJob 靠它重试（R-7.3）
class Alerts::DeliveryError < StandardError; end
