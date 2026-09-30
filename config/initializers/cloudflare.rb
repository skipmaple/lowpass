require "middleware/cloudflare/client_ip"

# 换成真实访客 IP（lib/middleware/cloudflare/client_ip.rb），紧跟在 Rails 算 remote_ip 的中间件后面：
# 登录回调限流与控制器都排在后面，读到的是换过的 IP
Rails.application.config.middleware.insert_after ActionDispatch::RemoteIp, Cloudflare::ClientIp
