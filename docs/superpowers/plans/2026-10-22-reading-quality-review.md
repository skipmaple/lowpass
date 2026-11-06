# 阅读品质复审与打磨

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for the frontend tasks and bounded parallel workers for independent content and keyboard regressions. Steps use checkbox syntax for tracking.

**Goal:** 在已批准的纸墨设计内，修正实际阅读中可证实的排版、内容与导航缺口，以评奖维度检验完整体验。

**Architecture:** 复用现有阅读列、Mixed 字体分段、原生锚点和目录返回装置；旧刊只在序列化时清洗正文。保留 D35 跨栏滚动与既有宽屏布局。

**Tech Stack:** Rails 8、React、TypeScript、CSS、Vitest、Minitest、Chrome。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md`、现行 PRD D24/D34/D35、`.claude/skills/lowpass-design-taste/SKILL.md`。

## Global Constraints

- 不增加颜色、字体、装饰文案或动画库；正文单栏，手机边距 24px。
- 普通桌面阅读列 780px；1920px 以上保留 PR #33 已交付的 920px 阅读列、16/64px 字号例外。
- 不写已发布刊期数据；不改抓取、收藏、登录或后台接口。
- 首屏资源 ≤ 300 KB，完整 `bin/ci` 为工程门禁。

## Review Focus

- 栏尾返回后焦点进入目录，下一次 Tab 能选择来源，Back 仍能恢复阅读位置。
- 空源、失败源与没有源站外链的来源仍能返回目录。
- 周刊长段与图片保持同一阅读列，320–2560px 无横向溢出。
- 中文贴边强调与英文标识符不能互相误伤，旧刊数据库内容不变。
- 目录聚焦时方向键不翻期，正文仍可用方向键翻期；减少动态效果与打印不退步。

## Tasks

- [x] 栏尾导航：前端回归先失败，添加原生返回链接和可聚焦目录；真实浏览器验证焦点、Tab 与历史。
- [x] 排版：周刊正文与配图使用 780/920px，理由复用 Mixed 并继承字号与行高；已检查实际截图和计算样式。
- [x] 内容：独立评审否决了旧正文再次清洗；改为保护原始代码，已存摘要只去已知 read-more 尾巴，旧正文原样。具体最终回归见品质记录。
- [x] 键盘：周刊目录方向键误翻期回归先失败，补齐忽略区后通过。
- [x] 验收：实际页面宽度矩阵、跨栏停顿/回退、键盘/打印/减少动态效果检查；独立设计与代码复审发现的问题已修正并重新跑完整 CI；证据与未验证边界见品质记录。

## Decisions

- 当前功能分支工作区最初干净，在此处继续打磨并保留可审阅 diff，不创建额外工作树。
- 视觉修改依据本轮实际截图与两路独立审查；不因“获奖”增加新视觉装置。
- 菜单 Tab/Shift+Tab 已由两名审查者用真实浏览器验证正确，不修改。
- 图片缺少尺寸已在受控延迟解码中复现推移；用户明确批准仅尺寸探测，方案见 `docs/design/notes/2026-10-22-image-dimensions-proposal.md`，不以猜测比例裁图。

## 已授权的图片尺寸补全

- [x] 独立缓存和迁移、浅 job、现有 tick 补跑、批量只读 props，未知与失败不阻塞页面。
- [x] HTTP 二进制前缀读取、总期限、逐跳公网校验、无视 Range 提早断开、无隐式重试。
- [x] PNG/GIF/JPEG/WebP 仅格式头解析，保守处理 EXIF 方向与截断，未知返回空。
- [x] 已知尺寸比例框与真实 width/height，完整适应不裁图；手机/桌面单图及多图解码前后的位置回归通过。
- [x] 独立评审发现前100张阻挡后续回填；新增跨批次红绿回归并修复，201张可全部推进。
- [x] 最终完整 CI：453前端、856 Rails/3763断言、72系统/628断言，首屏264.32 KB；结果与生产验收边界见 `docs/design/notes/2026-10-22-quality-review.md`。
