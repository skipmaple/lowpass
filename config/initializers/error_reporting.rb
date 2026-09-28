require "lowpass/error_log"

# 调度某一步、告警门面、搜索不可用都只 Rails.error.report 一下就接着走，没有订阅者这些报告哪儿也不去。
# 订阅者在 lib/ 里、启动时 require：Rails.error 会一直拿着这个实例，不能是随重载换掉的类
Rails.error.subscribe(Lowpass::ErrorLog.new)
