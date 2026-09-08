子集字体，仅供设计画板内嵌使用。

- `wenkai-sub.woff2`：霞鹜文楷 Screen v1.522（SIL OFL 1.1），只保留期头与标语用到的汉字、数字与标点。
- `maple-sub.woff2`：Maple Mono NL v7.9（SIL OFL 1.1），只保留 ASCII 与 · × – — … ▲ ★ ↑ →。

生成方式：`uvx --with brotli --from fonttools pyftsubset <源字体> --text=... --flavor=woff2`。
生产环境不使用这两个子集，按 ADR 与实现计划自托管完整拆片字体。
