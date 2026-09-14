# syntax=docker/dockerfile:1
# check=error=true

# 生产镜像，给 Kamal 用（ADR T4：起步单容器，Solid Queue 以 Puma 插件跑在 web 里；T5：阿里云轻量 x86_64）。
# 本地试构建：docker build -t lowpass .
# 三段：base（运行时依赖）→ build（编译 gem、npm ci、vite build）→ 最终镜像只带 gem 与应用代码，不带 node。

# RUBY_VERSION 要和 .ruby-version 一致；NODE_VERSION 和 mise.toml 一致（只在构建阶段用来跑 vite build）
ARG RUBY_VERSION=3.4.8
ARG NODE_VERSION=24
FROM docker.io/library/node:${NODE_VERSION}-bookworm-slim AS node
FROM docker.io/library/ruby:${RUBY_VERSION}-slim-bookworm AS base

WORKDIR /rails

# 运行时只要 libpq（postgresql-client 带上，方便 db:prepare 与排查）、jemalloc、curl（健康检查与排查）
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 生产环境变量；jemalloc 减内存与延迟
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# 构建阶段：编译 gem 与前端资源，用完即弃
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node 从官方镜像拷二进制进来，比 apt 与 node-build 都省事；npm / npx 是官方镜像里同样的符号链接
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# 先装 gem，再装 npm 包，最后拷代码：改代码不会让前两层的缓存失效
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1：QEMU 模拟下并行编译会触发 bootsnap 的一个 bug（rails/bootsnap#495）
    bundle exec bootsnap precompile -j 1 --gemfile

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# 前端资源：vite_rails 挂在 assets:precompile 上，输出到 public/vite；不需要真正的 master key
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

RUN rm -rf node_modules

# 最终镜像
FROM base

# 只以非 root 用户运行；只拷构建产物
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# 入口：起 server 时先 db:prepare（主库与队列库），其它命令原样执行
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster 在 80 端口前置 Puma：HTTP/2、静态资源缓存与压缩、X-Sendfile；kamal-proxy 连的就是这个口
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
