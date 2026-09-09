# Hacker News 样本

由 `script/capture_samples hn` 于 2026-09-09 抓取（`https://hacker-news.firebaseio.com/v0/topstories.json` 前 15 条及对应
`item/<id>.json`）。文件名保持 `item_<id>.json`（不加 `_job` 等后缀），因为测试按 `topstories.json` 里的 id 逐个用
`file_fixture` 加载。

## 手工修改

- **`item_49624603.json`**：字段 `title`。
  - 原文：`DeepSeek launching v4.1 flash cheaper and more capable than v4 pro`
  - 改为：`Ask HN: What do you think of DeepSeek's V4.1 Flash pricing change?`
  - 原因：任务要求样本里至少有一条无外链、标题以 `Ask HN` 开头的 story，用来测试「无外链的帖子指向讨论页」的兜底逻辑；抓到的 15
    条里没有天然的 Ask HN 帖。这条本来就是纯文字自帖（有 `text` 字段、没有 `url` 字段），是改动最小的候选——只改了标题，
    `url` 键本来就不存在，未新增删除动作。其余字段（`by`、`score`、`time`、`type`、`descendants`、`kids`、`text`）未改。
    这条排在 `topstories.json` 第 7 位，属于适配器 `count: 10` 会选中的前 10 条之一，所以它会出现在 `fetch` 的结果里。

- **`item_49625110.json`**：未改动。
  抓取下来天然就是 `"type": "job"`（`Roame (YC S23) Is Hiring Viral Content Editor`，score 1），满足任务要求「样本里至少有
  一条 job 类型」。它排在 `topstories.json` 第 14 位，排在适配器选够 10 条有效 story 之后，天然属于「不需要用来凑够 10 条
  story」的那一类,所以不用像 brief 里说的那样手工把某条 story 改成 job。

其余 13 条 item 文件均为抓取的原始内容，未作任何修改。
