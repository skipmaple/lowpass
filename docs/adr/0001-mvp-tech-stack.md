# ADR-0001：MVP 技术选型评估

| 状态 | 日期 | 选型人 | 评估 |
|---|---|---|---|
| Accepted，选型人于 2026-09-08 确认 T1 至 T7 | 2026-09-08 | 产品负责人 | Claude（架构视角） |

## 背景

选型：Rails 8 + Inertia.js + React + shadcn/ui；PostgreSQL；Kamal 2 最新版，单机部署。

来自 PRD v0.3 的硬约束：单人业余开发；用户不超过 100；月维护少于 1 小时；日刊 06:00 生成且后台可改；模糊搜索含中文免分词；Google 与 GitHub OAuth；登录后可读；无脚本可读已发布期（N-7、6.4）；每日备份并演练恢复（N-6）；单机或 Serverless 成本（N-10）。数据量约 3 万条每年。

## 结论

选型与"单人、单机、稳定优先"高度匹配，可以采用。Rails 8 的默认件（Solid Queue、Kamal、Thruster、`/up` 健康端点、认证生成器的 Session 结构）覆盖了 PRD 中调度、部署、健康检查、会话的大部分。开工前需定 7 项（T1 至 T7），其中 T1 与 PRD 的非功能要求直接冲突。

## 决议（2026-09-08）

| 编号 | 决议 | 说明 |
|---|---|---|
| T1 | A | 接受客户端渲染；PRD 删除 N-7 与 6.4 的无脚本要求；上线清单加大陆网络首屏实测不超过 1.5 秒 |
| T2 | A | 每分钟一次的调度检查任务，读数据库设置触发生成并补跑缺期；PRD R-1.1 补充精度说明 |
| T3 | A | PostgreSQL 作为 Kamal accessory；每日 pg_dump 推到香港区域对象存储 |
| T4 | B | web 与 job 两个角色、两个容器，同一镜像不同启动命令；Solid Queue 以独立进程跑在 job 容器，不用 Puma 插件；T2 的检查任务也在 job 容器。内存预算：系统 0.3、PostgreSQL 0.5、web 0.6、job 0.4 GiB，部署峰值再加一套 web 与 job，约 2.9 GiB，加 2 GiB swap |
| T5 | 香港 | 阿里云轻量 2 vCPU 4 GiB；域名不备案；镜像仓库 Docker Hub |
| T6 | A | TypeScript |
| T7 | A | PostgreSQL 内建搜索；上线前 50 条真实查询验证 |

## 补充（2026-09-09）：推荐理由需要的模型服务，T8 待定

PRD v0.3.3 新增 D16：每条条目带模型生成的推荐理由与兴趣标签。这是 MVP 唯一的外部模型依赖，供应商与调用方式由产品负责人决定，本节只列选项与事实，不给建议。

| 编号 | 问题 | 选项 | 事实与需要考虑的点 |
|---|---|---|---|
| T8 | 推荐理由用哪个模型服务，怎样调用 | A 直接调用一家模型供应商的 API；B 经统一网关调用，便于切换供应商与比价；C 自托管小模型 | 规模：每天约 30 次调用，每次输入不超过 1 千 token，输出不超过 100 token。时延不敏感：异步补写（PRD R-9.1），失败有兜底（R-9.6）。需要考虑：香港服务器到供应商的网络可达性；按量费用与 PRD N-10 的月上限；密钥只存环境变量；标题与摘要是否允许发给第三方；C 在 4 GiB 内存的机器上会挤占 web 与 job 的预算 |

对已接受决议的影响：T4 不变，理由生成作为 Solid Queue 任务跑在 job 容器；T2 不变，生成任务在期发布后入队。产品负责人定 T8 后，更新决议表并在实现计划里加上生成任务与后台的重生成入口。

**2026-09-11 产品负责人决定（PRD D23）**：T8 延后到 P2，随管理后台一起落地。供应商、模型名与月费用上限在 `/admin/settings` 配置，密钥只从环境变量读；接入层按可切换供应商设计，A 与 B 的取舍随后台配置决定，C 自托管不在 P2 范围。P0 不生成推荐理由，读者页已预留 `reason` 与 `interest_tag` 的渲染。实现计划在 P2 阶段编写，包含生成任务、后台配置页与重生成入口。

## 补充决议（2026-09-09）：借鉴 basecamp/fizzy 后由产品负责人定的四项

| 编号 | 决议 | 说明 |
|---|---|---|
| T9 | 主键照搬 fizzy：UUIDv7，base36 编码为 25 字符字符串列 | 在 PostgreSQL 上不用原生 uuid 列型；生成与 fixture 规则见 AGENTS.md |
| T10 | 引入 fizzy 的 `surfguard` gem 做出站请求的 SSRF 策略 | 管理员填的 feed 地址连接前解析为公网 IP，拒绝内网与回环 |
| T11 | 工具版本用 mise 管理 | `.mise.toml` 钉 Ruby 与 Node；`bin/setup` 负责安装；prek 不引入 |
| T12 | 引入 `mission_control-jobs` 作为队列面板 | 挂在 `/admin/jobs`，仅 admin |

四项都不改变 T1 到 T7 的结论；AGENTS.md 是代理执行时的默认值汇总。

## 逐项评估

| 组件 | 对 PRD 的覆盖 | 注意点 |
|---|---|---|
| Rails 8 | 控制器即页面数据源；Active Job 的重试对应 R-1.2；Solid Queue 递归任务对应 06:00 与 09:00 调度；`/up` 供 kamal-proxy 健康检查；认证生成器提供 Session 与 Current | 认证生成器是邮箱加密码，OAuth 需 OmniAuth（Google、GitHub 两个 strategy 加 CSRF 保护）；保留生成器的 Session 结构，替换登录方式。Solid Queue 递归任务是静态 cron 配置，时区可设 `SolidQueue.time_zone`，运行时改时间需另想办法，见 T2 |
| Inertia.js | 无需 API 层；路由、鉴权、CSRF 留在 Rails；部分重载与 URL 状态天然适合搜索页筛选（R-4.5）；延迟属性可后加载重栏目 | 默认客户端渲染，无 JS 时页面为空，与 N-7、6.4 冲突，见 T1。适配器由社区维护，活跃但非官方，锁版本并少用边缘特性 |
| React + shadcn/ui | 表格、表单、对话框、标签、空态一次到位，后台页面成本低；组件源码进仓库，无运行时依赖；Inertia Rails 官方有 shadcn 集成指南，生成器 `inertia:install --framework=react --vite --tailwind` 一步到位 | 需要 Vite（vite_rails）而非 Rails 8 默认的 Propshaft 加 importmap；Dockerfile 构建阶段需要 Node，运行阶段不需要（除非 SSR）。建议开 TypeScript，见 T6 |
| PostgreSQL | 数据量小，单实例足够；Solid Queue 与 Solid Cache 可共用同一实例的不同库；搜索需求可由内建能力满足，见 T7 | 作为 Kamal accessory 运行时没有自带备份，需自行安排，见 T3 |
| Kamal 2 | 单机零停机部署；kamal-proxy 自动 Let's Encrypt，前提是单服务器、显式 host、443 开放，与 PRD 单机一致；accessory 跑 PostgreSQL；roles 可随时拆出 job 容器；secrets 有 1Password 等适配 | 需要一个镜像仓库；Apple Silicon 本机构建 amd64 镜像要设 builder arch 或远程构建；服务器位置影响国内首屏与镜像拉取，见 T5 |

## 交叉关注点

- 时区：`config.time_zone` 与 `SolidQueue.time_zone` 均设 Asia/Shanghai，数据库存 UTC，与 PRD 3 一致。
- 抓取：Ruby 生态有成熟的 HTTP、HTML、RSS、Markdown 解析库，四个适配器可全部用 Ruby 实现，无需第二语言。
- 告警：Action Mailer 发邮件或直接 HTTP 调 IM webhook；失败任务可挂 Rails 官方的 Mission Control 面板给管理员看。
- 健康检查：`/up` 给 kamal-proxy；PRD N-5 要求的数据库、搜索、最近一期距今另做一个端点。
- 安全：Rails 默认 CSRF 与 Cookie 属性满足 N-3；`force_ssl` 开启；Vite 支持 CSP nonce。
- 测试：请求测试可断言 Inertia 组件与 props；系统测试跑真实浏览器；四个适配器用真实样本做解析测试。

## 待决事项

| 编号 | 问题 | 选项 | 建议 |
|---|---|---|---|
| T1 | 无脚本可读（N-7、6.4）与 Inertia 客户端渲染冲突 | A 修改 PRD，删去无脚本要求，保留首屏 300 KB 预算；B 开启 Inertia SSR，生产多跑一个 Node 进程，镜像含 Node，Kamal 多一个角色；C 阅读页用 ERB，后台用 Inertia，两套前端 | A。登录墙后无 SEO 需求，SSR 的收益只剩首屏几百毫秒，代价是常驻进程与构建复杂度。首屏预算作为守门指标，不达标再开 SSR |
| T2 | 调度时间要后台可改到分（R-1.1），而递归任务是静态配置 | A 每分钟跑一个 tick 任务，读数据库设置，到点则入队生成任务，同时检查当日缺期即补跑；B 改配置需重新部署 | A。一个 tick 同时实现 R-1.1 与 R-1.7，每天 1440 次空跑成本可忽略 |
| T3 | PostgreSQL 运行与备份 | A Kamal accessory 加每日 pg_dump 到对象存储，用备份容器或递归任务；B 托管 PostgreSQL | A。符合 N-10，恢复演练用 pg_restore 即可；数据超出单机或运维时间超预算时转 B |
| T4 | 进程拓扑 | A 单容器，Puma 内跑 Solid Queue 插件；B 拆 web 与 job 两个角色 | A 起步。每天几次抓取不值得两个容器；Kamal 改 roles 是配置级变更 |
| T5 | 服务器位置与镜像仓库 | A 国内 VPS，需域名备案，镜像仓库选国内可达；B 海外 VPS，无备案，国内首屏受延迟影响 | 由选型人定。N-1 的 1.5 秒按国内网络写，选 B 则需重估或加 CDN |
| T6 | TypeScript | A 开；B 不开 | A。props 契约是 Inertia 唯一的前后端接口，类型是唯一的护栏 |
| T7 | 搜索实现 | A PostgreSQL 内建：pg_trgm 做英文拼写容错与前缀，ILIKE 做中文子串，应用层做权重与高亮；B 专用搜索引擎 | A。3 万条每年的规模顺扫都够；封装为单一搜索服务，上线前按 PRD 11 用 50 条真实查询验证，不达标再换 B |

## 风险

| 风险 | 等级 | 应对 |
|---|---|---|
| Inertia Rails 适配器停更或落后于 Inertia 核心 | 中 | 锁版本；只用稳定特性；页面层薄，可迁 |
| 中文模糊搜索质量 | 中 | T7 的验证门槛；搜索服务可替换 |
| Kamal accessory 数据卷丢失 | 中 | T3 备份加恢复演练 |
| 单机故障 | 已接受 | N-2 允许维护窗口；告警覆盖 |
| 本机 arm64 构建与服务器 amd64 不一致 | 低 | builder arch 或远程构建 |
| 国内访问海外 VPS 延迟 | 视 T5 | T5 |

## 后果

- 更容易：单仓库单语言后端；无 API 契约维护；一条命令部署；调度与队列无外部依赖。
- 更难：前后端耦合在 props 契约上，靠 TypeScript 约束；日后若要 SSR 需加 Node 进程与角色。
- 需回访：搜索验证结果；tick 调度是否够用；何时拆 job 角色。

## 行动项

1. 选型人确认 T1 至 T7。
2. 按确认结果修订 PRD：T1 影响 N-7 与 6.4；T2 若接受 1 分钟粒度，R-1.1 措辞补一句。
3. 写实现计划，从 P0 抓取管道开工。

## 附：T1 详解

**PRD 里写了什么。** N-7 与 6.4 要求无脚本也能读已发布的期。写入时的理由是刊物应像静态页一样可靠、首屏不等 JS、渐进增强，当时未考虑前端方案。

**Inertia 的渲染方式。** 首次访问返回 HTML 壳，页面数据以 JSON 放在根节点属性里，浏览器执行 React 后才有内容；之后的导航是 XHR 取 JSON 局部更新。无 JS 时只有空壳。开启 SSR 后，首屏由 Node 进程用 renderToString 生成 HTML，浏览器再水合；链接是普通 a 标签，无 JS 时整页跳转仍可读；useForm 表单无 JS 不可用，除非写成原生表单。

**无 JS 在本产品中实际发生的场景。**

| 场景 | 在本产品中 |
|---|---|
| 用户禁用 JS | 技术读者中极少 |
| JS 包加载失败：网络抖动、拦截、部署切换瞬间 | Kamal 零停机与 Thruster 缓存降低概率但不为零，后果是白屏 |
| 不执行 JS 的机器读者：链接预览、稍后读、curl | D1 登录墙下只能看到登录页，此项无意义 |
| 旧浏览器 | N-7 已限定近两版 |

结论：登录墙后，无 JS 可读的实际价值只剩包加载失败时的鲁棒性，以及首屏快慢的观感。

**方案 A：改 PRD，接受客户端渲染。**

- 首屏需下载并执行 JS。gzip 后估算：React 与 ReactDOM 约 45 KB，Inertia 约 15 KB，shadcn 依赖的 Radix 约 30 到 60 KB，页面代码 30 到 80 KB，CSS 10 到 30 KB，合计约 150 到 250 KB，在 N-1 的 300 KB 预算内。国内服务器加桌面宽带约 0.5 到 1 秒可读，中端手机约 1 秒；海外服务器再加数百毫秒往返，约 1.5 到 3 秒。均为经验估算，上线前实测。
- 缓解：按页面切分代码（Inertia 的 import.meta.glob 天然按页分块）；根节点内放极简骨架；noscript 提示；HTTP/2、Brotli、不可变资源缓存；React 错误边界避免整页白屏。
- 代价：零开发与运维成本；放弃包加载失败时的鲁棒性。
- 需改：删 N-7 的无脚本要求与 6.4 末条；N-1 首屏预算保留并作守门。

**方案 B：开启 Inertia SSR。**

- 需要：Vite 开 ssrBuildEnabled，SSR 入口用 createServer 与 renderToString；构建产出 public/assets-ssr/inertia.js，生产用 node 运行，默认监听 13714，Rails 每次渲染页面向它发 HTTP 请求；镜像需含 Node 运行时。
- Kamal 形态：同容器双进程需要进程管理器，因为 Kamal 每容器一个启动命令；或拆一个 ssr 角色，Rails 用 ssr_url 指向它。多一个需监控、重启、占约 100 到 200 MB 内存的进程。
- 风险：Inertia Rails 文档把 SSR 标为实验特性；组件必须 SSR 安全，渲染期不能访问 window 等，Radix 支持 SSR，自写组件要注意；水合不一致会报警；SSR 失败有 on_ssr_error 回调，从设计看应回退到客户端渲染，实现时用故意关掉 SSR 进程验证一次。
- 收益：首屏直接出 HTML，慢网络下观感明显更好；阅读页无 JS 可读；若日后 D1 改为公开阅读，SEO 已就位。
- 变体 B'：期发布后不可变，可在发布时用同一 SSR 入口渲染一次并存 HTML，请求路径不依赖 Node。复杂度接近 B，但把风险从请求路径挪到发布任务。MVP 不建议，记录备用。

**方案 C：阅读页 ERB，后台 Inertia。**

- 阅读页（首页、日刊、周刊、归档、搜索）本质是列表，Rails 视图直接输出 HTML，天然无 JS 可读、包体极小；搜索筛选用原生表单。后台与设置用 Inertia、React、shadcn。
- 代价：两套 UI 技术，顶栏等布局在 ERB 与 React 各写一份，样式靠 Tailwind 共享但组件不共享；阅读页日后加交互要另用 Stimulus 或 Turbo。
- 极端形态 C'：全站 Rails 视图加 Hotwire，不用 React。与选型相悖，仅作参照。

**判断依据。**

1. 服务器在国内还是海外（T5）：海外时 A 的首屏最吃亏，B 的收益最大。
2. 对包加载失败白屏的容忍度：能接受偶发刷新即好，选 A。
3. 是否愿意生产常驻 Node 进程并承担实验特性风险：不愿意则排除 B。
4. D1 未来是否可能改公开：可能则 B 的 SEO 价值提前显现。
5. 月维护 1 小时的预算：B 最挤占。

## 附：服务器事实与 T1、T5 判断（2026-09-08）

服务器：阿里云轻量应用服务器，中国香港，国际型 2 vCPU、4 GiB、ESSD 50 GiB，Ubuntu 24.04，到期 2027-04-25。

**T5 由此明确。** 香港节点无需备案；Docker Hub、GHCR、Let's Encrypt 均可直达；大陆读者到香港往返约 30 到 100 毫秒，远好于欧美节点。N-1 的 1.5 秒首屏按此网络评估可达。轻量服务器有带宽峰值与月流量包上限，需在控制台确认数值；按 100 人以内、静态资源强缓存估算，流量远低于上限。

**T1 判断：选 A，接受客户端渲染，修改 PRD 的 N-7 与 6.4。** 理由：香港节点下 A 的首屏估算约 1 秒，B 的收益只剩几百毫秒；4 GiB 内存能容纳 SSR 进程，但月维护 1 小时的预算容不下一个实验特性的常驻进程；登录墙让无 JS 可读的机器读者场景失效。守门条件：上线前用大陆网络实测日刊详情页首屏，若超过 1.5 秒，先做代码分块与资源缓存，仍超则启用 B'（发布时预渲染）而非 B。

**该机型对其余待决项的影响。**

| 项 | 影响 |
|---|---|
| T3 | 数据库以 accessory 跑在同机可行；每日 pg_dump 建议推到同区域对象存储，不要只留本机磁盘 |
| T4 | 单容器起步合适。内存预算：系统约 0.3 GiB，PostgreSQL 约 0.3 到 0.5 GiB，Puma 两个 worker 约 0.6 GiB，kamal-proxy 很小；Kamal 零停机部署时新旧应用容器短暂并存，峰值再加一个应用的内存，仍在 4 GiB 内。建议加 2 GiB swap 作保险 |
| 磁盘 | 50 GiB 足够，镜像每版约 0.5 到 1 GiB，依赖 Kamal 的保留数量与定期清理 |
| 安全 | 轻量服务器防火墙只放 22、80、443；SSH 仅密钥登录 |
