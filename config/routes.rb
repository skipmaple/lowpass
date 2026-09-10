Rails.application.routes.draw do
  # D20：`/` 就是最新一期日刊，不是单独的首页；两条路由渲染同一个 Inertia 页面。
  root "daily_issues#latest"

  resources :daily_issues, path: "daily", only: [ :index, :show ], param: :period_key
  resources :weekly_issues, path: "weekly", only: [ :index, :show ], param: :period_key

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
