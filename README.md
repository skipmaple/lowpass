# Lowpass

个人技术刊物站：每天 06:00（Asia/Shanghai）把 Hacker News、GitHub Trending、Hackaday 装订成一期不可变的日刊，
每周收进阮一峰周刊；信息源可配置，历史可搜索，Google / GitHub 登录，单租户。

产品需求见 [PRD](docs/superpowers/specs/2026-09-08-mvp-prd.md)，技术选型与决议见
[ADR](docs/adr/0001-mvp-tech-stack.md)；工程约定与不变量见 [AGENTS.md](AGENTS.md)，代码风格见
[STYLE.md](STYLE.md)；界面像素依据是[设计画布](https://claude.ai/code/artifact/31a80ae3-1e5f-4551-ac1e-d56f9dab0556)
与 `.claude/skills/lowpass-design-taste/` 里的设计令牌。

开发环境搭建跑 `bin/setup`，日常开发跑 `bin/dev`，提交前的合并门禁是 `bin/ci`；细节见
[docs/development.md](docs/development.md)。
