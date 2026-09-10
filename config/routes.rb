Rails.application.routes.draw do
  # D20：`/` 就是最新一期日刊，不是单独的首页；两条路由渲染同一个 Inertia 页面。
  root "daily_issues#latest"

  resources :daily_issues, path: "daily", only: [ :index, :show ], param: :period_key
  resources :weekly_issues, path: "weekly", only: [ :index, :show ], param: :period_key

  # 队列面板：P0 只在开发环境挂载，免认证（config/environments/development.rb 关掉了它默认的
  # HTTP Basic Auth，本来就没提交凭证）。生产环境挂载与管理员认证是 P2，见 AGENTS.md 的 `/admin/jobs`。
  mount MissionControl::Jobs::Engine, at: "/jobs" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # 兜底：站内没有的地址也给附录 B 的 404 页（带报头与页脚），不是 public/404.html 那张静态页。
  # 必须排在最后，前面每条路由都先匹配。静态资源由 ActionDispatch::Static 在路由之前接走。
  match "*path", to: "errors#not_found", via: :all
end
