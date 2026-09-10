# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  # package.json 的 check 脚本就是这个项目的类型检查（tsc -p tsconfig.app.json && tsc -p tsconfig.node.json）。
  step "Frontend: typecheck", "npm run check"
  step "Frontend: audit", "npm audit --audit-level=high"
  step "Frontend: build", "npm run build"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # config/vite.json 的 test 环境开着 autoBuild，并行测试 worker 第一次请求时都会触发构建，
  # 撞在一起偶尔会炸成 "Vite test manifest missing entrypoints/application.css"。这里先单独
  # 构建一次测试包挡住这个竞态；autoBuild 本身留着，单独跑 bin/rails test 不受影响。
  # RAILS_ENV=test 不能少：vite_rails 的 CLI 扩展会在解析 --mode 之前先 `require config/environment`
  # 把 Rails 应用整个启动起来，ViteRuby 的配置这时候已经按 Rails.env 定死了（没设就是 development），
  # 之后再来的 --mode test 已经晚了，产物会悄悄写进 public/vite-dev 而不是 public/vite-test。
  step "Frontend: build for tests", "env RAILS_ENV=test bin/vite build --mode test"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
