Rails.application.routes.draw do
  # D20：`/` 就是最新一期日刊，不是单独的首页；两条路由渲染同一个 Inertia 页面。
  root "daily_issues#latest"

  # P2-① 登录（PRD 5.5）：POST /auth/:provider 与回调的前半段在 OmniAuth 中间件里（config/initializers/omniauth.rb），
  # 回调后半段落到 sessions#create；失败由 OmniAuth.config.on_failure 直接调 sessions#failure，这条路由只是兜底
  get "login" => "sessions#new", as: :login
  get "auth/:provider/callback" => "sessions#create", as: :auth_callback
  get "auth/failure" => "sessions#failure"
  delete "session" => "sessions#destroy", as: :session
  get "settings" => "settings#show", as: :settings

  resources :daily_issues, path: "daily", only: [ :index, :show ], param: :period_key
  resources :weekly_issues, path: "weekly", only: [ :index, :show ], param: :period_key

  # P1 搜索（PRD 5.4）：GET /search 是搜索页，参数见 R-4.5；POST /search/clicks 记结果点击（9.1 search_click）
  resource :search, only: :show, controller: "searches"
  namespace :search do
    resources :clicks, only: :create
  end

  # 队列面板：P0 只在开发环境挂载，免认证（config/environments/development.rb 关掉了它默认的
  # HTTP Basic Auth，本来就没提交凭证）。生产环境挂载与管理员认证是 P2，见 AGENTS.md 的 `/admin/jobs`。
  mount MissionControl::Jobs::Engine, at: "/jobs" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # 兜底：站内没有的地址也给附录 B 的 404 页（带报头与页脚），不是 public/404.html 那张静态页。
  # 必须排在最后，前面每条路由都先匹配。静态资源由 ActionDispatch::Static 在路由之前接走。
  # 只接 GET（HEAD 由 Rack::Head 折算成 GET）：非 GET 方法（POST 等）没有路由可落，交给
  # ActionController::RoutingError，走 show_exceptions 的常规 404，不然会先撞见 CSRF 校验，
  # 未带令牌的非 GET 请求就变成 422 而不是 404。
  match "*path", to: "errors#not_found", via: :get
end
