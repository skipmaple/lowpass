# 生产模型专用出口与费用

2026-11-06 用户确认：仅生产环境的 OpenAI 请求经洛杉矶 Tailscale 出口；连接不可用或 OpenAI 可用额度耗尽时，直连硅基流动的 `deepseek-ai/DeepSeek-V4-Flash`。开发环境继续使用本地服务，其他流量不改路由。

## 出口与凭据

在专用 Ubuntu 24.04 洛杉矶节点运行 `script/setup_openai_egress LA_TAILSCALE_IP HK_TAILSCALE_IP`。Tinyproxy 仅绑定 Tailnet IPv4 的 8888 端口，只接收香港节点，只允许 `api.openai.com:443` 的 CONNECT。TLS 在 Rails 与 OpenAI 之间完成，代理不保存密钥。专用 systemd 服务 `lowpass-openai-egress.service` 限制 64 MiB，默认发行版 tinyproxy 服务保持 masked。

GitHub 仓库的 production Environment Secrets：

- `OPENAI_API_KEY`：OpenAI 项目密钥。
- `MODEL_OPENAI_PROXY_URL`：`http://LA_TAILSCALE_IP:8888`。
- `MODEL_API_KEY`：保留现有硅基流动密钥。
- `MODEL_FALLBACK_NAME`：`deepseek-ai/DeepSeek-V4-Flash`。
- `MODEL_FALLBACK_INPUT_PRICE` / `MODEL_FALLBACK_OUTPUT_PRICE`：仅未知备用模型需要的 CNY / 百万 token 费率；已支持的 V4-Flash 按下面分时费率。

GitHub Actions → Kamal → 容器环境注入。不要把凭据放到代理、后台表单、日志、PR 或仓库中。

## 选择与切换

主模型配置：`https://api.openai.com/v1`，`gpt-6-luna`，输入 0.10、输出 0.50 USD / 百万 token，月上限 0。请求显式关闭推理。只有日刊有理由；现有 D38/D39、可用正文要求、译文、幂等与管理员停止规则保留。

只在以下情况转备用一次：

1. 模型 POST 发出之前，代理 TCP / CONNECT 上游连接失败。
2. OpenAI 明确返回额度耗尽：429 的 `credit_balance_exhausted`、`insufficient_quota`，或无 code 且 type 为 `insufficient_quota`。

普通限流、401/403、证书错误和无效输出不触发备用。请求发出后的断线交给现有有限重试，避免隐藏重复计费。每个后续请求重新尝试 OpenAI，因此网络恢复、下期额度到账后自动优先主模型。备用也失败时保留原重试上限，不循环换供应商。

用户确认没有另购余额、未启用自动充值。促销额度耗尽可据 API 错误切换；如果未来充值或启用自动充值，OpenAI 会继续使用付费余额，本实现无法从普通项目密钥判断余额来源，不代表促销额度专用限额。

## 账本

每次调用记录实际供应商、模型、币种、输入/输出 token、缓存读取/写入 token、当次费率、费用和切换原因。费用保留八位小数。USD 与 CNY 分组显示，不做换汇或相加。硅基流动不设独立额度上限。

截至 2026-11-06 的公开单价，均按百万 token：

| 模型 | 币种 | 普通输入 | 缓存输入 | 缓存写入 | 输出 |
| --- | --- | ---: | ---: | ---: | ---: |
| GPT-6 Luna | USD | 0.10 | 0.01 | 0.125 | 0.50 |
| DeepSeek-V4-Flash，上海 02:00–08:00 | CNY | 1.50 | 0.15 | 普通输入价 | 4.50 |
| DeepSeek-V4-Flash，其他时段 | CNY | 3.00 | 0.30 | 普通输入价 | 9.00 |

价格来源：[OpenAI 模型页](https://developers.openai.com/api/docs/models/gpt-6-luna)、[硅基流动 2026-08-25 分时定价公告](https://docs.siliconflow.cn/docs/release-notes/overview)。账本是基于响应 token 的估算，供应商实际账单为准；改变备用模型时需重新核实价格。

## 验收与回退

- 香港宿主及应用容器通过代理访问 OpenAI：不带密钥的 `/v1/models` 应返回 401；其他域名、其他 Tailnet 客户端应被拒绝。
- 部署后用受控小请求核实主模型。通过单次冻结配置的不可连接代理端口模拟故障，核实备用和 CNY 账本；不停止整机 Tailscale、不批量重生历史内容。
- 额度耗尽以离线契约测试验证，不为验收消耗用户额度。
- 检查 `/health`、应用队列、默认路由，确认开发配置不变。
- 紧急回退可将后台主模型恢复硅基流动端点与现有模型，币种 CNY、月上限 0；不要删密钥或改系统代理。回退版本前先恢复模型配置。新增账本列保留即可，不在生产降精度回滚迁移。
