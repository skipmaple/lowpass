source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# json 3.0 改了 JSON.parse 的参数签名，ActiveSupport::JSON.decode（jsonb 列读写都走它）传两个位置参数会报
# ArgumentError；锁在 2.x 直到 Rails 跟上 json 3.0。.github/dependabot.yml 里同步挡住了 json 的大版本
# 升级，解锁时两处一起改。
gem "json", "< 3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

gem "inertia_rails", "~> 3.6"
gem "vite_rails", "~> 3.0"
gem "rss"                     # Ruby 3.4 起是 bundled gem，必须显式声明
gem "nokogiri"
gem "surfguard", github: "basecamp/surfguard"
gem "mission_control-jobs"

# 登录（PRD 5.5，设计 docs/superpowers/specs/2026-09-13-p2-login-design.md）：OmniAuth 只做「从 provider 拿到资料」这一步，
# 匹配、合并、会话都在我们的代码里。omniauth-rails_csrf_protection 让 /auth/:provider 只接受带 CSRF 令牌的 POST。
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-github", "~> 2.0"
gem "omniauth-rails_csrf_protection", "~> 2.0"

group :development, :test do
  gem "webmock"
  gem "mocha"
end
