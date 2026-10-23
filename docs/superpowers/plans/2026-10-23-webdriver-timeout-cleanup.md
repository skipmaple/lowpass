# 系统等待超时后的 WebDriver 连接清理

PR #75 首轮 CI 在滚动恢复等待处超时，随后截图依次读到了数字、数组。原始滚动超时原因尚未确定；独立 loopback 实验已证明默认 `Timeout.timeout` 会使当前 Selenium / Net::HTTP 复用未读完的连接。

1. 添加调用实际 `ApplicationSystemTestCase#wait_until` 的真实 Selenium HTTP 回归。夹具保留 execute 响应直到超时后才释放，不启动浏览器、不访问外网。先确认旧实现截图收到数字而失败。
2. 仅显式指定 `Timeout::Error`，使 Net::HTTP 关闭被打断的连接。保留五秒参数、轮询间隔、所有页面条件与断言。
3. 验证超时后截图、窗口列表与再次截图正确，并完成本地完整 CI、独立审查、Draft PR 和最新提交远端门禁。

范围仅为已证实的 execute POST 响应错位。Net::HTTP 对幂等请求另有重试行为；不声称所有谓词都具有精确的物理五秒截止时间，也不将此修复作为原始滚动恢复超时的根因证明。
