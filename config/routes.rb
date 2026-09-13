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

  # P2-② 管理后台（PRD 5.3、5.6）：CRUD 资源（STYLE.md），全部继承 Admin::BaseController。
  # 启停是 enablement 资源（POST 启用 / DELETE 停用）；某期某源重抓、补生成、立即生成今日日刊各是一个资源
  namespace :admin do
    root to: redirect("/admin/sources")
    resources :sources, except: [ :destroy, :show ] do
      resource :enablement, only: [ :create, :destroy ], module: :sources
      resources :runs, only: :index, module: :sources
    end
    resources :test_fetches, only: :create, controller: "sources/test_fetches"
    resources :issues, only: :index, param: :period_key, constraints: { period_key: /\d{4}-\d{2}-\d{2}|\d{4}-W\d{2}/ } do
      resource :refetch, only: :create, module: :issues
      resource :backfill, only: :create, module: :issues
    end
    resource :today_issue, only: :create
    resources :users, only: :index
    resource :settings, only: [ :show, :update ]
  end

  # 队列面板（ADR T12）：三个环境都挂在 /admin/jobs，认证由 Admin::BaseController 做（config/application.rb）。
  # /admin 下其余路径先过 admin 检查再落 404（AC-3.5：非 admin 访问 /admin 下任意路径都是 403）；
  # 子项目 ② 的后台页面加在这一段前面。
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"
  match "admin(/*path)" => "admin/base#not_found", via: :get

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
