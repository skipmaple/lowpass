# 品质提升（以评奖为标尺）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 lowpass 的读者界面打磨到设计说明第 1 节的标尺：修掉评估里的缺陷，补齐排版细节、构图与工程细节，加上一套只表达纸与墨的动效，然后按截图矩阵与评分表反复自查到达标。

**Architecture:** 只在既有的 Rails + Inertia/React 前端上加改，不加依赖。静态视觉规则追加在 `app/frontend/styles/tokens.css` 末尾的「2026-10-14 品质提升」段；动效集中在新文件 `styles/motion.css`，打印在 `styles/print.css`；交互逻辑放进小而专的 `lib/*.ts`（翻页、开场、打印、正文字体）。CSS 的行为用一个把生产样式表装进 data URL 的系统测试来量，组件逻辑用 Vitest，页面级行为用真浏览器系统测试。

**Tech Stack:** Rails 8.1、Inertia 3.7（`viewTransition` 访问选项）、React 19、Radix Tabs、Vitest + Testing Library、Minitest + Capybara/Selenium（headless Chrome、CDP 模拟视口与媒体）。

**Spec:** `docs/superpowers/specs/2026-10-14-award-quality-design.md`（v1.1，O1 选 b、O2 选 a）。执行前先读它；任务里的 Q/T/C/M/E/D 编号都指它。

## Global Constraints

- 颜色只用 6 个令牌（PAPER `#E8E3DA`、INK `#1D1D1B`、INK2 `#55504B`、GREEN `#96B59F`、RULE `rgba(29,29,27,0.35)`；GROUND 不用于读者页）；字体 4 个角色；字号只用 12/13/15/20/22/26/32/40/56（≥1920px 另有 16/64）。不加装饰文案。报头不加任何元素。
- 动效令牌：`--dur-1: 120ms`、`--dur-2: 240ms`、`--dur-3: 360ms`；`--ease-out: cubic-bezier(0.2, 0.7, 0.2, 1)`、`--ease-move: cubic-bezier(0.65, 0, 0.35, 1)`。只动 transform、opacity、clip-path、stroke-dashoffset 和颜色类属性；不动布局；不引入动画库。
- 系统「减少动态效果」开启时所有状态瞬间切换；开场与日出直接显示最终画面。
- 首屏 ≤ 300 KB（`script/first_screen_size`）；本次新增 JS ≤ 3 KB、CSS ≤ 4 KB（均为 gzip，D4）；CLS 保持 0；触控目标 ≥ 44 × 44。
- 期发布后不可变：不改库里已发布的条目，展示层的清洗只在读出时做。
- 新的静态样式写在 `tokens.css` 末尾的「2026-10-14 品质提升」段（文件前面同一选择器有多层覆盖，写在末尾才是定论）；动效写在 `motion.css`，打印写在 `print.css`。不改前面已有的声明，除非任务明确要求。
- 测试不连网。Vitest 不编译 CSS（`css: false`），样式行为一律放进 `test/system/design_rules_test.rb` 量。单个系统测试文件用 `mise exec -- bin/rails test test/system/<file>.rb` 跑（`bin/rails test:system FILE` 会忽略文件过滤）；跑真页面的系统测试前先 `env RAILS_ENV=test mise exec -- bin/vite build --mode test`。
- 提交信息用中文，带尾注 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`；本机提交用 `git -c commit.gpgsign=false commit`。git 命令单独执行，不与其他命令用 `&&`、`;`、管道拼在一起（本机的命令守卫会拒绝）。

## Review Focus

1. 320px 宽、最长的兴趣标签（「智能家居 / IoT」）跟在两行英文标题后面：页面不横向溢出，标签整块换到下一行行首，不靠右悬挂。（Task 4 的系统测试）
2. 连续快速切换两个来源：墨块最后停在当前来源上，裁切与当前项重合，不卡在中间。（Task 6 的系统测试）
3. 连按 → 或连点「后一期」：上一次翻页的方向标记不残留到下一次；按住方向键不放（`repeat`）不连翻。（Task 8 的单测）
4. 收藏请求失败回滚：墨退下，`data-stamp` 一起去掉，书签不卡在压下的状态。（Task 7 的单测）
5. 打印一期有失败来源、或正在生成的日刊：失败来源印出它的事实句；期级事实句只印一次。（Task 13 的单测）

---

### Task 1: 规则落文档（PRD D34、设计 skill 的「动效」一节与令牌）

**Files:**
- Modify: `docs/superpowers/specs/2026-09-08-mvp-prd.md`（第 5 行版本、6.3、6.4、7.5、第 12 节 D34、修订记录）
- Modify: `.claude/skills/lowpass-design-taste/SKILL.md`
- Modify: `.claude/skills/lowpass-design-taste/reference/lowpass-tokens.md`

**Interfaces:**
- Consumes: 设计说明第 4.4、5、6 节。
- Produces: 后续任务引用的规则文字（D34、「动效」一节、动效令牌表）。

- [ ] **Step 1: 改 PRD 头部版本**

第 5 行改成：

```markdown
| lowpass | v0.4.3 草案 | 细化版，待审核 | 2026-10-14 | Claude（PM 视角） | 产品负责人 |
```

- [ ] **Step 2: 第 12 节在 D33 那一行之后加 D34**

```markdown
| D34 | 界面的动效、键盘翻页与打印 | 动效只表达纸与墨：来源索引条的墨块平移、换期翻页、收藏盖章、悬停墨线、首次打开的出刊顺序、登录页日出、弹层；时长 120 / 240 / 360ms 三档、缓动两种，只动变换、透明度、裁切与颜色，不动布局；系统「减少动态效果」开启时全部关闭。日刊与周刊详情页按 ← / → 翻到前一期 / 后一期（焦点在输入框、索引条、菜单、对话框里时不翻），页面上不加说明文字。打印时日刊印出全部来源，隐藏书签、导航等交互件。2026-10-14 产品负责人选定，设计见 `docs/superpowers/specs/2026-10-14-award-quality-design.md`。 | 6.3、6.4 |
```

- [ ] **Step 3: 6.3 末尾加一条，6.4 末尾加一条**

在 6.3「读者恢复与反馈」那一条之后加：

```markdown
- **动效（D34）**：只用设计 skill「动效」一节的令牌与时刻；系统开启「减少动态效果」时所有状态瞬间切换。
```

在 6.4 第二条（触控目标与无障碍）之后加：

```markdown
- 日刊、周刊详情页支持 ← / → 翻到前一期 / 后一期（D34）；打印时日刊印出全部来源，隐藏书签、导航等交互件（D34）。
```

- [ ] **Step 4: 7.5 第一句后补一句**

把 7.5 的「摘要去 HTML 标签与 Markdown 标记、」改成「摘要先去掉源站附加的「阅读更多」链接（如 Hackaday 摘要末尾的 …read more），再去 HTML 标签与 Markdown 标记、」，其余不动。

- [ ] **Step 5: 修订记录最上面加 v0.4.3**

```markdown
- v0.4.3 草案 · 2026-10-14 · 品质提升（以评奖为标尺，设计见 `docs/superpowers/specs/2026-10-14-award-quality-design.md`）：新增 D34（动效、键盘翻页、打印），6.3、6.4 引用；7.5 补一条清洗规则（去掉源站附加的阅读更多链接）。范围不变。
```

- [ ] **Step 6: 设计 skill `SKILL.md` 三处修改**

（a）「结构装置」里「列表单栏、十条一致」那一条之后加：

```markdown
- 兴趣标签紧跟标题最后一个词（所有宽度同一条规则，2026-10-14 产品负责人选定）；放不下就整个换到下一行行首，不靠右悬挂。书签在行末自己的一列。
```

（b）在「## 文案」之前插入新的一节：

```markdown
## 动效

动效表达材料，不表达自己。只有三个动作：墨走（反白块与墨线移动）、翻页（换一期）、盖章（确认）。不弹跳、不发光、不视差、不随滚动播放、不接管滚动、不循环。系统「减少动态效果」开启时，所有状态瞬间切换，开场与日出直接显示终态。

- 令牌（值在 `app/frontend/styles/motion.css`）：`--dur-1` 120ms（颜色、下划线、图标填充、菜单展开）；`--dur-2` 240ms（墨块平移、盖章、按钮漫墨、弹层、列表换入）；`--dur-3` 360ms（翻页、开场）；`--ease-out` cubic-bezier(0.2, 0.7, 0.2, 1)（出现、停稳）；`--ease-move` cubic-bezier(0.65, 0, 0.35, 1)（从 A 到 B）。更长的一次性插图动画（登录页日出）用这几档相加，不另起数值。
- 只动 transform、opacity、clip-path、stroke-dashoffset 与颜色类属性；不动布局；不引入动画库。
- 时刻（PRD D34）：墨块平移（切来源）；翻页（前一期 / 后一期与 ← / →；其余整页跳转只淡入淡出）；盖章（收藏）；墨线（悬停：链接下划线加深，描边按钮墨从底部漫满；可选中的控件悬停只加下划线，反白专指选中）；开场（每个标签页会话首次整页加载，≤ 600ms）；日出（登录页，约 1 秒，一次）；弹层（菜单、对话框、提示条、目录项淡入）。新动效先问「它是这三个动作之一吗」，不是就不加。
```

（c）「交付前自检」末尾加第 8 条：

```markdown
8. 动效只用两种缓动、三档时长（或它们相加），只动合成属性；减少动态效果时全部关闭。
```

并在「常见偏差」表末尾加一行：

```markdown
| 给新控件加弹跳、回弹缩放或随滚动触发的入场 | 只用墨走、翻页、盖章三个动作；入场只在开场与弹层，且只播一次 |
```

- [ ] **Step 7: `reference/lowpass-tokens.md` 两处修改**

（a）「已用的装置」里「条目」那一条，把「标签紧随标题，与正文处于同一阅读组。」改成「标签紧跟标题最后一个词（所有宽度，2026-10-14 O1），放不下整个换到下一行行首；书签在行末自己的一列。」

（b）文件末尾加：

```markdown
## 2026-10-14 品质提升（已批准，设计说明 `docs/superpowers/specs/2026-10-14-award-quality-design.md`）

| 动效令牌 | 值 |
|---|---|
| `--dur-1` | 120ms |
| `--dur-2` | 240ms |
| `--dur-3` | 360ms |
| `--ease-out` | cubic-bezier(0.2, 0.7, 0.2, 1) |
| `--ease-move` | cubic-bezier(0.65, 0, 0.35, 1) |

- 插图新增两幅：「翻开的书」（周刊来源横带的图形，`SourceMark` 体系，反白时挖空填墨）、「缺页」（404 / 403，对折的报纸被裁去一块，缺口里是 45° 排线）。
- 选区反白：墨底纸字。中西文自动间距只开在来自源站与模型的内容上；界面日期等保持紧排。
- 来源索引条相邻的边合成一条 1px（含索引条与列表之间那条）。
- 周刊配图正片叠底压进纸面（O2）；打印时恢复原样。
- 打印：白底墨字，墨带改成墨字加 2px 线；日刊印出全部来源，每个来源前印来源名；书签、导航、按钮、索引条不印；条目不跨页；标题后用 Maple 12 印域名。
```

- [ ] **Step 8: 提交**

```bash
git add docs/superpowers/specs/2026-09-08-mvp-prd.md .claude/skills/lowpass-design-taste/SKILL.md .claude/skills/lowpass-design-taste/reference/lowpass-tokens.md
```

```bash
git -c commit.gpgsign=false commit -m "文档：PRD D34（动效、键盘翻页、打印）与设计 skill 的「动效」一节" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 内容清洗——去掉「read more」，片段不切开连字符词（E1、E2）

**Files:**
- Modify: `app/models/summary_cleaner.rb`
- Modify: `app/models/search/highlighter.rb:83-86`（`latin_boundary?`）
- Modify: `app/controllers/searches_controller.rb`（`entry_props` 的 `snippet_runs`）
- Modify: `app/controllers/favorites_controller.rb`（`entry_props` 的 `snippet`）
- Test: `test/models/summary_cleaner_test.rb`、`test/models/search/highlighter_test.rb`、`test/controllers/searches_controller_test.rb`

**Interfaces:**
- Consumes: 无。
- Produces: `SummaryCleaner.clean` 去掉 `a.read-more` / `a.more-link` 与结尾的「…read more」；`Search::Highlighter#snippet` 不在连字符、撇号、斜线连起来的词中间起止。

- [ ] **Step 1: 写失败的清洗测试**

加到 `test/models/summary_cleaner_test.rb` 末尾（`end` 之前）：

```ruby
  # Hackaday 的 RSS 摘要末尾带一个 class="read-more" 的链接，文字是「…read more」：那是源站的导航，不是摘要（PRD 7.5）
  test "去掉源站附加的阅读更多链接" do
    html = %(<div><img src="x.jpg"></div>The progression of the web browser. Today <a href="https://hackaday.com/x/" class="read-more">&#8230;read more</a>)
    assert_equal "The progression of the web browser. Today", SummaryCleaner.clean(html)
    assert_equal "Keep going", SummaryCleaner.clean(%(Keep going <a class="more-link" href="/x">Continue reading</a>))
  end

  # 已发布的旧条目库里存着清洗过的「…read more」；页面数据会再过一遍 clean，只去结尾这一种，正文里的不动
  test "已存摘要结尾的…read more 去掉，别处的不动" do
    assert_equal "so too does the", SummaryCleaner.clean("so too does the …read more")
    assert_equal "Today", SummaryCleaner.clean("Today …Read More ")
    assert_equal "Why you should read more books", SummaryCleaner.clean("Why you should read more books")
    assert_equal "…read more in the middle stays", SummaryCleaner.clean("…read more in the middle stays")
  end

  test "Hackaday 样本的摘要都不带阅读更多" do
    xml = Nokogiri::XML(file_fixture("rss/hackaday.xml").read)
    summaries = xml.xpath("//item/description").map { |node| SummaryCleaner.clean(node.text) }

    assert_equal 7, summaries.size
    assert summaries.none? { |summary| summary.match?(/read more/i) }, summaries.grep(/read more/i).inspect
  end
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- bin/rails test test/models/summary_cleaner_test.rb`
Expected: 3 个新测试 FAIL（实际值结尾带「…read more」）。

- [ ] **Step 3: 实现清洗**

`app/models/summary_cleaner.rb`：在 `EMPHASIS` 常量之后加两个常量，改 `normalize` 与 `strip_html`：

```ruby
  # 源站附加的「阅读更多」链接不是摘要（PRD 7.5）：Hackaday 用 a.read-more，WordPress 默认主题用 a.more-link
  READ_MORE = "a.read-more, a.more-link".freeze
  # 已发布的旧条目库里存着清洗过的「…read more」：读出时再过一遍 clean，只去结尾这一种（期发布后不改库）
  READ_MORE_TAIL = /[[:space:]]*…[[:space:]]*read more[[:space:]]*\z/i
```

```ruby
      def normalize(text)
        s = strip_markdown(strip_html(text))
        CGI.unescapeHTML(s).gsub(/[[:space:]]+/, " ").strip.sub(READ_MORE_TAIL, "")
      end
```

```ruby
      def strip_html(text)
        fragment = Nokogiri::HTML.fragment(text)
        fragment.css(READ_MORE).each(&:remove)
        fragment.text
      end
```

- [ ] **Step 4: 跑，确认通过**

Run: `mise exec -- bin/rails test test/models/summary_cleaner_test.rb`
Expected: 全部 PASS。

- [ ] **Step 5: 写失败的片段边界测试**

加到 `test/models/search/highlighter_test.rb` 末尾（`end` 之前）：

```ruby
  # F7：片段起点落在连字符上（「Production-grade」的 -）时，挪到下一个词的开头，不从「-grade」开始
  test "连字符连起来的词也不从中间切开" do
    body = joined(highlighter("agent").snippet("Production-grade engineering skills for AI coding agents."))

    assert_equal "…engineering skills for AI coding agents.", body
  end
```

再加到 `test/controllers/searches_controller_test.rb` 末尾（`end` 之前）：

```ruby
  # 旧条目库里存着「…read more」：片段先过一遍清洗（PRD 7.5），不把源站的尾巴带进结果
  test "片段不带源站附加的阅读更多" do
    index_item("Negative resistance explained", summary: "A look at negative resistance that goes further than expected …read more")

    get search_path(q: "negative resistance")

    snippet = page_props["results"].first["snippet_runs"].map { |run| run["text"] }.join
    assert_no_match(/read more/i, snippet)
  end
```

- [ ] **Step 6: 跑，确认失败**

Run: `mise exec -- bin/rails test test/models/search/highlighter_test.rb test/controllers/searches_controller_test.rb`
Expected: 两个新测试 FAIL（片段以「…-grade」开头；片段带「…read more」）。

- [ ] **Step 7: 实现**

`app/models/search/highlighter.rb`，替换 `latin_boundary?`：

```ruby
    # 切点两侧都不是空白、都不是中日韩字符，且至少一侧是拉丁字母数字：切在这里就是切在词中间。
    # 连字符、撇号、斜线连起来的「Production-grade」「agent-skills」也算一个词（设计说明 2026-10-14 E2）
    def latin_boundary?(text, at)
      before, after = text[at - 1], text[at]
      return false if before.nil? || after.nil?
      return false if [ before, after ].any? { |char| char.match?(/[[:space:]]/) || char.match?(Search::Query::CJK) }

      [ before, after ].any? { |char| char.match?(LATIN) }
    end
```

`app/controllers/searches_controller.rb` 的 `entry_props` 里：

```ruby
        snippet_runs: item.summary.presence && highlighter.snippet(SummaryCleaner.clean(item.summary))
```

`app/controllers/favorites_controller.rb` 的 `entry_props` 里：

```ruby
        snippet: Search::Highlighter.excerpt(SummaryCleaner.clean(favorite.summary)),
```

- [ ] **Step 8: 跑，确认通过（含原有片段测试）**

Run: `mise exec -- bin/rails test test/models/search/highlighter_test.rb test/controllers/searches_controller_test.rb test/controllers/favorites_controller_test.rb test/models/summary_cleaner_test.rb`
Expected: 全部 PASS。原有「边界内的短词仍然不被切开」等测试不受影响。

- [ ] **Step 9: 提交**

```bash
git add app/models/summary_cleaner.rb app/models/search/highlighter.rb app/controllers/searches_controller.rb app/controllers/favorites_controller.rb test/models/summary_cleaner_test.rb test/models/search/highlighter_test.rb test/controllers/searches_controller_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "内容：摘要去掉源站的「阅读更多」，搜索片段不切开连字符词" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: 排版与缺陷样式（T1、T2、T3、T5、T6、Q1、Q2、Q3、Q5）

**Files:**
- Create: `test/system/design_rules_test.rb`
- Modify: `app/frontend/styles/tokens.css`（文件末尾新增「2026-10-14 品质提升」段）

**Interfaces:**
- Consumes: 无。
- Produces: `DesignRulesTest#render_fragment(html, width:, height:, reduced_motion:, media:)`——后面 Task 4、5、10、13 往这个文件里加用例；`tokens.css` 末尾段落标题 `/* ─── 2026-10-14 品质提升`，后面任务往这一段追加。

- [ ] **Step 1: 写失败的系统测试**

新建 `test/system/design_rules_test.rb`：

```ruby
require "application_system_test_case"
require "base64"

# 设计说明 2026-10-14 里能用计算样式与几何量出来的规则。直接把生产 CSS 和最小的 HTML 片段装进一页
# （同 paper_test），不经 Vite、不登录：量的是样式表本身。动效与打印的样式表还没建时就跳过它们。
class DesignRulesTest < ApplicationSystemTestCase
  STYLES = %w[ tokens.css motion.css print.css ].freeze
  PAPER = "rgb(232, 227, 218)".freeze
  INK = "rgb(29, 29, 27)".freeze

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "", features: [])
  end

  test "Q1 周刊来源横带里的图标与文字是纸色" do
    render_fragment(%(<div class="source-band"><svg viewBox="0 0 10 10" fill="none" stroke="currentColor"><path d="M0 0L10 10"/></svg></div>))

    assert_equal PAPER, style(".source-band svg", "color")
  end

  test "Q2 折叠目录没有默认三角，换成会转的 chevron" do
    render_fragment(%(<details class="weekly-directory"><summary>板块目录</summary><p>x</p></details>))

    assert_not_equal "list-item", style("summary", "display")
    assert_includes style("summary", "mask-image", "::before"), "url("
    assert_equal "none", style("summary", "rotate", "::before")

    execute_script("document.querySelector('details').open = true")
    assert_equal "90deg", style("summary", "rotate", "::before")
  end

  test "Q3 索引条相邻的边与下面的列表线都合成一条 1px" do
    [ 1440, 375 ].each do |width|
      render_fragment(<<~HTML, width: width)
        <div class="source-tabs"><button class="source-tab">A</button><button class="source-tab">B</button><button class="source-tab">C</button></div>
        <div class="issue-body"><p>x</p></div>
      HTML
      tabs = evaluate_script("[...document.querySelectorAll('.source-tab')].map((tab) => tab.getBoundingClientRect().toJSON())")
      body = evaluate_script("document.querySelector('.issue-body').getBoundingClientRect().toJSON()")

      assert_in_delta 0, tabs[0]["left"], 0.5, "#{width}px：最左一条贴齐版心"
      assert_in_delta tabs[0]["right"] - 1, tabs[1]["left"], 0.5, "#{width}px：第一、二条共用一条边"
      assert_in_delta tabs[1]["right"] - 1, tabs[2]["left"], 0.5, "#{width}px：第二、三条共用一条边"
      assert_in_delta tabs[0]["bottom"] - 1, body["top"], 0.5, "#{width}px：索引条底边与列表顶线合成一条"
    end
  end

  test "Q5 手机上评论链接的触控区 44px，元数据行仍是 24px 高" do
    render_fragment(%(<div style="padding: 60px"><div class="item-meta"><a class="item-metric item-comments" href="#c"><span>6</span></a></div></div>), width: 375, height: 812)

    assert_operator evaluate_script("document.querySelector('.item-meta').getBoundingClientRect().height"), :<=, 24.5
    hits = evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector('.item-comments').getBoundingClientRect()
        const cx = r.left + r.width / 2, cy = r.top + r.height / 2
        return [[cx, cy - 21], [cx, cy + 21], [cx - 21, cy], [cx + 21, cy]].map(([x, y]) => document.elementFromPoint(x, y)?.closest('.item-comments') !== null)
      })()
    JS
    assert_equal [ true, true, true, true ], hits
  end

  test "T1 内容文字开中西文间距，界面日期保持紧排" do
    render_fragment(%(<p class="item-reason">涉及AI模型</p><p class="item-translation">OpenAI工程师</p><h1 class="issue-head-date">10月14日</h1>))

    assert_equal "normal", style(".item-reason", "text-autospace")
    assert_equal "normal", style(".item-translation", "text-autospace")
    assert_equal "no-autospace", style(".issue-head-date", "text-autospace")
  end

  test "T2 标题均衡换行，段落避免孤字" do
    render_fragment(%(<div class="item-heading"><h2 class="item-title">Title</h2></div><span class="item-summary">Summary</span><div class="item-reason">理由</div>))

    assert_equal "balance", style(".item-heading", "text-wrap-style")
    assert_equal "pretty", style(".item-summary", "text-wrap-style")
    assert_equal "pretty", style(".item-reason", "text-wrap-style")
  end

  test "T3 选区是墨底纸字" do
    render_fragment(%(<p class="item-reason">理由</p>))

    assert_equal INK, style(".item-reason", "background-color", "::selection")
    assert_equal PAPER, style(".item-reason", "color", "::selection")
  end

  test "T5 墨底纸字用灰度抗锯齿；T6 滚动条用令牌色" do
    render_fragment(%(<header class="masthead"><a class="masthead-brand">lowpass</a></header>))

    assert_equal "antialiased", style(".masthead", "-webkit-font-smoothing")
    assert_equal "rgba(29, 29, 27, 0.35) rgba(0, 0, 0, 0)", style("html", "scrollbar-color")
  end

  private
    def render_fragment(html, width: 1440, height: 900, reduced_motion: false, media: "")
      css = STYLES.filter_map { |name| Rails.root.join("app/frontend/styles", name) }.select(&:exist?).map(&:read).join("\n")
      browser = page.driver.browser
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      browser.execute_cdp("Emulation.setEmulatedMedia", media: media, features: [ { name: "prefers-reduced-motion", value: reduced_motion ? "reduce" : "no-preference" } ])
      document = "<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'><style>#{css}</style></head><body class='paper'>#{html}</body></html>"
      visit "data:text/html;charset=utf-8;base64,#{Base64.strict_encode64(document)}"
    end

    def style(selector, property, pseudo = nil)
      evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}), #{pseudo.to_json}).getPropertyValue(#{property.to_json})")
    end
end
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb`
Expected: 8 个测试 FAIL（例如 Q1 得到 `rgb(29, 29, 27)`；Q3 相邻差 2px；T1 得到 `no-autospace`）。

- [ ] **Step 3: 实现——在 `tokens.css` 文件末尾追加**

```css
/* ─── 2026-10-14 品质提升（docs/superpowers/specs/2026-10-14-award-quality-design.md）────────────────
   写在文件末尾：前面同一选择器有好几层覆盖，放这里才是最后的定论。后续任务往这一段追加。 */

/* T1 中西文自动间距只给来自源站与模型的内容；界面字（期头日期、归档日期、状态句里的 9月7日、按钮）保持已定的紧排 */
.item-title, .item-translation, .item-summary, .item-reason, .item-content--weekly, .source-band-issue, .search-title, .search-snippet { text-autospace: normal; }

/* T2 标题均衡换行（不剩单个词），段落避免末行孤字 */
.item-heading, .search-title, .state-line { text-wrap: balance; }
.item-translation, .item-summary, .item-reason, .item-content--weekly p, .search-snippet, .dialog-text { text-wrap: pretty; }

/* T3 选区反白：墨底纸字（浏览器的蓝色选区是令牌之外的颜色） */
::selection { background: var(--ink); color: var(--paper); }

/* T5 墨底上的纸色字用灰度抗锯齿，字不发胖 */
.masthead, .login-band, .source-tab[data-state="active"], .source-band, .btn-primary, .chip-on, .seg-item[aria-current="true"], .admin-nav-item[aria-current="page"] {
  -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale;
}

/* T6 滚动条用令牌色：35% 墨的滑块、透明轨道（macOS 的悬浮滚动条不受影响，不占版面宽度） */
html { scrollbar-color: var(--rule) transparent; }

/* Q1 横带里的文字与图标统一取纸色：图标用 currentColor，原先继承了墨，墨画在墨上看不见 */
.source-band { color: var(--paper); }

/* Q2 所有折叠目录：去掉浏览器默认的三角，换成与搜索筛选折叠钮同款的 chevron（Lucide chevron-right、1.75 描边），展开转 90° */
details > summary { list-style: none; display: flex; align-items: center; gap: 8px; }
details > summary::-webkit-details-marker { display: none; }
details > summary::before {
  content: ""; flex: none; width: 14px; height: 14px; background: currentColor;
  mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='1.75' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m9 18 6-6-6-6'/%3E%3C/svg%3E") center / contain no-repeat;
}
details[open] > summary::before { rotate: 90deg; }

/* Q3 索引条相邻的边合成一条 1px：每条向左压 1px 叠住左邻的右边、向下压 1px 让下一行（与下面列表的顶线）叠住底边；
   容器左边补回 1px，最左一条仍贴齐版心。墨块副本（M1）用同一组类名，位置跟着一致 */
.source-tabs { padding-left: 1px; }
.source-tabs > .source-tab { margin: 0 0 -1px -1px; }

/* Q5 评论链接：44px 触控区由伪元素扩出，元数据行回到 24px 高（手机上原先被 min-height 撑高，间距忽大忽小） */
.item-comments { position: relative; }
.item-comments::after { content: ""; position: absolute; left: 50%; top: 50%; width: max(100%, 44px); height: 44px; transform: translate(-50%, -50%); }
@media (max-width: 480px) {
  .item-comments { min-height: 0; min-width: 0; }
}
```

- [ ] **Step 4: 跑，确认通过**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb test/system/paper_test.rb`
Expected: 全部 PASS（`paper_test` 不受影响）。断言里的计算值格式（`text-wrap-style`、`::selection`、`scrollbar-color`、`::before` 的 `rotate` 与 `mask-image`）已在 Chrome 152 上核对过。

- [ ] **Step 5: 在开发环境目测一遍**

本地起 `bin/rails server -p 3000` 与 `bin/vite dev`（不要用 `bin/dev`），用内置浏览器打开最新日刊与周刊详情：横带图标可见、目录前是 chevron、索引条线宽一致、推荐理由里「AI 模型」有间距、选中文字是墨底纸字。

- [ ] **Step 6: 提交**

```bash
git add app/frontend/styles/tokens.css test/system/design_rules_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "排版：中西文间距、均衡换行、反白选区；修横带图标、目录三角、索引条双线与评论触控区" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 条目标题组——标签紧跟标题，序号与期头对齐基线（Q4、C4、T4）

**Files:**
- Modify: `app/frontend/components/ItemRow.tsx`（标题组结构与注释）
- Modify: `app/frontend/styles/tokens.css`（品质提升段末尾追加）
- Test: `test/frontend/components/ItemRow.test.tsx`、`test/system/design_rules_test.rb`

**Interfaces:**
- Consumes: Task 3 的 `render_fragment`。
- Produces: 条目标题组 DOM：`.item-heading > (h2|h3|h4).item-title + span.item-tag`，标签不在标题元素里；`.item-heading--tagged` 不再使用。

- [ ] **Step 1: 改单测为新结构（先失败）**

`test/frontend/components/ItemRow.test.tsx` 里「有值时理由成段、标签使用低对比度的描边样式」整条换成：

```tsx
  it('有值时理由成段；标签紧跟在标题元素后面，不进标题的可读名称', () => {
    const { container } = render(
      <ItemRow item={item({ reason: '与你关注的终端工具相关。', interest_tag: 'AI' })} adapter="hacker_news" rank={1} />,
    )

    expect(screen.getByText('与你关注的终端工具相关。')).toHaveClass('item-reason')
    const heading = screen.getByRole('heading', { level: 2 })
    expect(container.querySelector('.item-heading')).not.toHaveClass('item-heading--tagged')
    expect(heading.nextElementSibling).toHaveClass('item-tag')
    expect(heading).not.toHaveTextContent('AI')
    expect(container.querySelector('.item-tag .item-interest-chip')).toHaveClass('chip-outline')
  })
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/components/ItemRow.test.tsx`
Expected: 这一条 FAIL（`.item-heading` 仍带 `item-heading--tagged`）。

- [ ] **Step 3: 改 `ItemRow.tsx`**

文件头注释里「标签锚定条目行末端；窄屏自然换行，仍属于同一阅读组。」改成「兴趣标签紧跟标题最后一个词（所有宽度，2026-10-14 O1）：标题元素行内排，标签是它后面的行内小签，放不下就整个换到下一行行首。」

标题组那一段换成：

```tsx
        {/* 第二轮阅读评审：完整显示标题和摘要；外链仍在新标签页打开。标签在标题元素外面：不进标题的可读名称 */}
        <div className="item-heading">
          <Heading className="item-title">
            <a className="t" href={item.url} target="_blank" rel="noopener noreferrer" lang={latinLang(item.title)}>
              {item.title}
            </a>
          </Heading>
          {tagged ? (
            <span className="item-tag"><Chip text={item.interest_tag!} variant="outline" className="item-interest-chip" /></span>
          ) : null}
        </div>
```

- [ ] **Step 4: 跑单测，确认通过**

Run: `mise exec -- npx vitest run test/frontend/components/ItemRow.test.tsx`
Expected: 全部 PASS。

- [ ] **Step 5: 写失败的几何测试**

加到 `test/system/design_rules_test.rb` 的 `private` 之前：

```ruby
  ITEM = <<~HTML.freeze
    <div style="padding: 0 24px"><article class="item-row"><span class="item-rank">2</span><div class="item-body">
      <div class="item-heading"><h2 class="item-title"><a class="t" href="#">%<title>s</a></h2><span class="item-tag"><span class="chip-outline item-interest-chip">%<tag>s</span></span></div>
    </div></article></div>
  HTML

  test "Q4/C4 兴趣标签紧跟标题末尾，放不下就整个换到下一行行首" do
    [ 1440, 1024, 375, 320 ].each do |width|
      render_fragment(format(ITEM, title: "OpenAI engineer arrested in bugging of executive conference room", tag: "智能家居 / IoT"), width: width)
      placed = evaluate_script(<<~JS)
        (() => {
          const rects = [...document.querySelector('.item-title a').getClientRects()]
          const last = rects[rects.length - 1]
          const tag = document.querySelector('.item-tag').getBoundingClientRect()
          const heading = document.querySelector('.item-heading').getBoundingClientRect()
          const sameLine = Math.abs(tag.bottom - last.bottom) <= 6 && tag.left >= last.right
          const nextLineStart = tag.top >= last.bottom - 1 && Math.abs(tag.left - heading.left) <= 1
          return sameLine || nextLineStart
        })()
      JS
      assert placed, "#{width}px：标签应在标题末尾或下一行行首"
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, evaluate_script("document.documentElement.clientWidth"), "#{width}px：不横向溢出"
    end
  end

  test "T4 序号与标题首行同一条基线；期头小字末行与大字日期同一条基线" do
    render_fragment(<<~HTML)
      #{format(ITEM, title: "Gemini 4 Argon", tag: "AI / LLM")}
      <header class="page-head"><div class="issue-head-main"><div class="issue-head-title"><h1 class="issue-head-date">10月14日</h1><div class="issue-head-stack"><span class="issue-head-calendar">2026 年 · 星期三</span><span class="issue-head-time">06:00 发布</span></div></div></div></header>
    HTML
    baseline = <<~JS
      ((selector) => { const el = document.querySelector(selector); const probe = document.createElement('span'); probe.style.cssText = 'display:inline-block;width:0;height:0;vertical-align:baseline'; el.appendChild(probe); const y = probe.getBoundingClientRect().top; probe.remove(); return y })
    JS

    assert_in_delta evaluate_script("#{baseline}('.item-rank')"), evaluate_script("#{baseline}('.item-title a')"), 1
    assert_in_delta evaluate_script("#{baseline}('.issue-head-date')"), evaluate_script("#{baseline}('.issue-head-time')"), 1
  end
```

- [ ] **Step 6: 跑，确认失败**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb`
Expected: Q4/C4 与 T4 FAIL（标签不在标题行内；序号与标题基线差约 4px）。

- [ ] **Step 7: 实现——`tokens.css` 品质提升段末尾追加**

```css
/* Q4 / C4（O1 选 b）：兴趣标签紧跟标题最后一个词——标题元素行内排，标签是行内小签，基线对齐标题；
   放不下就整个换到下一行行首。所有宽度同一条规则；书签仍在行末自己的一列。 */
.item-heading { display: block; max-width: 780px; }
.item-heading > .item-title { display: inline; }
.item-tag { display: inline-flex; vertical-align: baseline; margin-left: 10px; padding-top: 0; }
@media (min-width: 1920px) { .item-heading { max-width: 920px; } }

/* T4 序号与标题首行同一条基线（桌面两列时）；期头右侧小字的最后一行落在大字日期的基线上 */
.item-rank, .item-body { align-self: baseline; }
.item-rank { padding-top: 0; }
.issue-head-title { align-items: last baseline; }
.issue-head-stack { padding-bottom: 0; }
@media (max-width: 767px) {
  /* 手机上序号与书签同一行、正文另起一行，没有可对的基线 */
  .item-rank, .item-body { align-self: auto; }
}
```

- [ ] **Step 8: 跑，确认通过**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb`
Expected: 全部 PASS。

- [ ] **Step 9: 目测 1440、768、390、320 四个宽度的日刊**

用内置浏览器（`resize_window` 设宽度）看：标签贴着标题末尾或在下一行行首；书签右缘与正文右缘对齐不变；期头小字末行落在大字基线上。

- [ ] **Step 10: 提交**

```bash
git add app/frontend/components/ItemRow.tsx app/frontend/styles/tokens.css test/frontend/components/ItemRow.test.tsx test/system/design_rules_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "条目：兴趣标签紧跟标题末尾（所有宽度），序号与期头小字对齐基线" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 动效基础——令牌、悬停墨线、弹层（M4、M7）

**Files:**
- Create: `app/frontend/styles/motion.css`
- Modify: `app/frontend/entrypoints/application.css`（在 tokens.css 之后引入 motion.css）
- Test: `test/system/design_rules_test.rb`

**Interfaces:**
- Consumes: Task 3 的 `render_fragment`（会自动读到 motion.css）。
- Produces: CSS 变量 `--dur-1/2/3`、`--ease-out`、`--ease-move`；关键帧 `lp-fade`、`lp-rise`、`lp-settle`、`lp-drop`、`lp-unfold`（后续任务复用）；减少动态效果的全局收敛规则。

- [ ] **Step 1: 写失败的系统测试**

加到 `test/system/design_rules_test.rb` 的 `private` 之前：

```ruby
  test "M 动效令牌就这五个" do
    render_fragment("<p>x</p>")

    root = ->(name) { evaluate_script("getComputedStyle(document.documentElement).getPropertyValue(#{name.to_json}).trim()") }
    assert_equal "120ms", root.("--dur-1")
    assert_equal "240ms", root.("--dur-2")
    assert_equal "360ms", root.("--dur-3")
    assert_equal "cubic-bezier(0.2, 0.7, 0.2, 1)", root.("--ease-out")
    assert_equal "cubic-bezier(0.65, 0, 0.35, 1)", root.("--ease-move")
  end

  test "M4 描边按钮悬停时墨从底部漫满、字转纸色；不可点的没有" do
    render_fragment(%(<div style="padding: 40px"><a class="ctrl" href="#p">前一期</a> <span class="ctrl ctrl-off">后一期</span></div>))

    assert_equal "matrix(1, 0, 0, 0, 0, 0)", style(".ctrl:not(.ctrl-off)", "transform", "::before")
    find("a.ctrl").hover
    wait_until { style("a.ctrl", "color") == PAPER }
    wait_until { style("a.ctrl", "transform", "::before") == "matrix(1, 0, 0, 1, 0, 0)" }
    assert_equal "none", style(".ctrl-off", "content", "::before")
  end

  test "M4 未选中的索引条与分段控件悬停只加下划线，不反白" do
    render_fragment(%(<div class="source-tabs"><button class="source-tab" data-state="active"><span class="source-tab-name">A</span></button><button class="source-tab" data-state="inactive"><span class="source-tab-name">B</span></button></div>))

    find(".source-tab[data-state='inactive']").hover
    wait_until { style(".source-tab[data-state='inactive'] .source-tab-name", "text-decoration-color") == INK }
    assert_not_equal INK, style(".source-tab[data-state='inactive']", "background-color")
  end

  test "M7 菜单、对话框、提示条带出现动画；减少动态效果时几乎为零" do
    render_fragment(%(<div class="menu-card">菜单</div><div class="dialog">问句</div><div class="toast">提示</div>))
    assert_equal "lp-unfold", style(".menu-card", "animation-name")
    assert_equal "lp-settle", style(".dialog", "animation-name")
    assert_equal "lp-drop", style(".toast", "animation-name")

    render_fragment(%(<div class="menu-card">菜单</div><a class="ctrl" href="#p">前一期</a>), reduced_motion: true)
    assert_equal "0.001s", style(".menu-card", "animation-duration")
    assert_equal "0.001s", style(".ctrl", "transition-duration", "::before")
  end
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb`
Expected: 4 个新测试 FAIL（变量为空、没有 `::before`、没有动画名）。

- [ ] **Step 3: 新建 `app/frontend/styles/motion.css`**

```css
/* 动效（设计 skill「动效」、PRD D34、设计说明 2026-10-14 第 4.4 节）。
   只有三个动作：墨走、翻页、盖章。只动 transform、opacity、clip-path、stroke-dashoffset 与颜色类属性，不动布局。
   令牌只有这五个；新动效先问「它是这三个动作之一吗」，不是就不加。 */

:root {
  --dur-1: 120ms;
  --dur-2: 240ms;
  --dur-3: 360ms;
  --ease-out: cubic-bezier(0.2, 0.7, 0.2, 1);
  --ease-move: cubic-bezier(0.65, 0, 0.35, 1);
}

@keyframes lp-fade { from { opacity: 0; } }
@keyframes lp-rise { from { opacity: 0; transform: translateY(6px); } }
@keyframes lp-settle { from { opacity: 0; transform: translateY(8px); } }
@keyframes lp-drop { from { opacity: 0; transform: translateY(-8px); } }
@keyframes lp-unfold { from { clip-path: inset(0 0 100% 0); } to { clip-path: inset(0 0 0 0); } }

/* ─── M4 墨线 ─────────────────────────────────────────────────────────── */

/* 链接下划线由 30% 墨加深到实墨；原先悬停才画下划线的几处改成常驻透明下划线，悬停只换颜色，才过渡得起来 */
a.t, .link-button, .archive-key, .search-original { transition: text-decoration-color var(--dur-1) linear, color var(--dur-1) linear; }
.menu-item, .directory-return, .source-band-link {
  text-decoration: underline; text-decoration-thickness: 1px; text-underline-offset: 4px; text-decoration-color: transparent;
  transition: text-decoration-color var(--dur-1) linear, color var(--dur-1) linear;
}
.menu-item:hover, .directory-return:hover { text-decoration-color: var(--ink); }
.source-band-link:hover { text-decoration-color: var(--paper); }

/* 描边按钮悬停：墨从底部漫满、字转纸色。墨是一层伪元素做纵向缩放（只动 transform），看到的是实墨块，不是渐变 */
.ctrl:not(.ctrl-off):not(:disabled) { position: relative; isolation: isolate; transition: color var(--dur-1) linear; }
.ctrl:not(.ctrl-off):not(:disabled)::before {
  content: ""; position: absolute; inset: 0; z-index: -1; background: var(--ink);
  transform: scaleY(0); transform-origin: 50% 100%; transition: transform var(--dur-2) var(--ease-out);
}
@media (hover: hover) and (pointer: fine) {
  .ctrl:not(.ctrl-off):not(:disabled):hover { color: var(--paper); }
  .ctrl:not(.ctrl-off):not(:disabled):hover::before { transform: scaleY(1); }
}

/* 可选中的控件（来源索引条、分段控件）反白专指选中：未选中项悬停只给名字加 1px 下划线 */
.source-tab .source-tab-name, .seg-item {
  text-decoration: underline; text-decoration-thickness: 1px; text-underline-offset: 4px; text-decoration-color: transparent;
  transition: text-decoration-color var(--dur-1) linear;
}
@media (hover: hover) and (pointer: fine) {
  .source-tab[data-state="inactive"]:hover .source-tab-name, .seg-item:not([aria-current="true"]):hover { text-decoration-color: currentColor; }
}

/* ─── M7 弹层 ─────────────────────────────────────────────────────────── */

.menu-card { animation: lp-unfold var(--dur-1) var(--ease-out); }
.dialog-shade { animation: lp-fade var(--dur-2) var(--ease-out); }
.dialog { animation: lp-settle var(--dur-2) var(--ease-out); }
.toast { animation: lp-drop var(--dur-2) var(--ease-out); }
/* 周刊「板块目录」展开：目录项淡入；版面本身不做高度动画（不动布局） */
details[open] > .anchors { animation: lp-rise var(--dur-2) var(--ease-out); }

/* ─── 减少动态效果 ───────────────────────────────────────────────────── */

/* 所有状态瞬间切换。留 1ms 而不是 0：animationend / transitionend 照常触发，靠它们收尾的代码（盖章）不会卡住 */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 1ms !important; animation-delay: 0ms !important;
    transition-duration: 1ms !important; transition-delay: 0ms !important;
  }
}
```

- [ ] **Step 4: 引入**

`app/frontend/entrypoints/application.css` 第 4 行 `@import "../styles/tokens.css";` 之后加一行：

```css
@import "../styles/motion.css";
```

- [ ] **Step 5: 跑，确认通过**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb`
Expected: 全部 PASS（`scaleY(0)` 的计算值是 `matrix(1, 0, 0, 0, 0, 0)`，headless Chrome 匹配 `(hover: hover) and (pointer: fine)`，均已核对）。

- [ ] **Step 6: 目测**

内置浏览器里悬停「前一期」「归档」：墨从底部漫上来、字转纸色；悬停未选中的索引条只出下划线；打开头像菜单向下展开。系统设置里开「减少动态效果」（或用 `resize_window` 的 colorScheme 之外的 CDP 模拟）确认全部瞬切。

- [ ] **Step 7: 提交**

```bash
git add app/frontend/styles/motion.css app/frontend/entrypoints/application.css test/system/design_rules_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "动效：令牌、悬停墨线、弹层出现；减少动态效果时全部瞬切" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 墨块平移（M1）

**Files:**
- Modify: `app/frontend/components/SourceTabs.tsx`
- Modify: `app/frontend/styles/motion.css`
- Create: `test/system/motion_test.rb`
- Test: `test/frontend/components/SourceTabs.test.tsx`

**Interfaces:**
- Consumes: Task 3 的 Q3（索引条叠边规则，副本用同一组类名）；Task 5 的 `--dur-2`、`--ease-move`、`lp-rise`。
- Produces: `export function inkInset(frame: { width: number; height: number }, tab: Box): string` 与 `export type Box`；DOM：`.source-tabs-frame[data-ink]` 包住 `Tabs.List.source-tabs` 与 `div.source-tabs.source-tabs-ink[aria-hidden]`；面板 `Tabs.Content.source-panel[data-switched]`。`MotionTest`（后续任务往里加用例）。

- [ ] **Step 1: 写失败的单测**

加到 `test/frontend/components/SourceTabs.test.tsx`：顶部 import 改成 `import SourceTabs, { inkInset } from '@/components/SourceTabs'`，文件末尾加：

```tsx
describe('墨块平移（M1）', () => {
  it('inkInset 把当前项相对容器的位置换成 inset(上 右 下 左)', () => {
    expect(inkInset({ width: 900, height: 104 }, { left: 299, top: 24, width: 301, height: 80 })).toBe('inset(24px 300px 0px 299px)')
  })

  it('inkInset 四舍五入到 0.01px', () => {
    expect(inkInset({ width: 100.004, height: 10 }, { left: 33.333, top: 0, width: 33.333, height: 10 })).toBe('inset(0px 33.34px 0px 33.33px)')
  })

  // jsdom 没有布局：量不到位置就不叠副本，当前项照旧自己反白（跟以前一样）
  it('量不到位置时不叠反白副本', () => {
    const { container } = renderTabs()

    expect(container.querySelector('.source-tabs-ink')).toBeNull()
    expect(container.querySelector('.source-tabs-frame')).not.toHaveAttribute('data-ink')
  })

  it('首次渲染的面板不带换入动画，切换之后的才带', async () => {
    const user = userEvent.setup()
    render(<Harness onSelect={vi.fn()} />)

    expect(screen.getByRole('tabpanel')).not.toHaveAttribute('data-switched')
    await user.click(screen.getAllByRole('tab')[1])
    expect(screen.getByRole('tabpanel')).toHaveAttribute('data-switched')
  })
})
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/components/SourceTabs.test.tsx`
Expected: FAIL（`inkInset` 未导出、没有 `.source-tabs-frame`）。

- [ ] **Step 3: 重写 `SourceTabs.tsx`**

```tsx
import { Tabs } from 'radix-ui'
import { useLayoutEffect, useRef, useState } from 'react'
import type * as React from 'react'

import { SourceMark } from '@/components/Illustration'
import { latinLang } from '@/lib/typeset'
import type { SourceSummary } from '@/types/lowpass'

// 来源切换：三条并排的纸报式索引条，当前项反白成墨块，其余 1px 描边；
// 44px 墨线图标 + 来源名 Newsreader 600。手机三格横排、图标在上名字在下。
// 竖排书脊方案被产品负责人否过（round-9 笔记），不要再提。
// 一次只显示一个来源（PRD 6.2）：条目已经全在 props 里，切换是本地状态，不回服务端。
// 画布：docs/design/src/pages_front3.py 的 tabs() 与 tabs_m()。
//
// 墨块平移（设计 skill「动效」M1）：索引条上叠一份 aria-hidden 的反白副本，clip-path 只露出当前项；
// 换来源时过渡 clip-path，墨块从旧来源滑到新来源，块里的字始终是纸色、块外是墨色。点击、焦点、读屏都还是
// 下面那条真的索引条（副本 pointer-events: none、inert）。量不到位置（还没布局、jsdom）就不叠副本，
// 当前项照旧自己反白。

// 栏级状态直接标在索引条的名字下面（PRD 6.2）；ok 与 pending 不占这一行。
// 用画布 tabs(kickers=…) 的短形：这一行是索引条上的小字，长句留给列表区。
const STATE_LINES: Record<SourceSummary['state'], string | null> = {
  ok: null,
  pending: null,
  failed: '抓取失败',
  empty: '本期无新内容',
  no_backfill: '无法回填',
}

export type Box = { left: number; top: number; width: number; height: number }

// 当前项相对索引条容器的位置换成 clip-path 的 inset(上 右 下 左)，四舍五入到 0.01px
export function inkInset(frame: { width: number; height: number }, tab: Box): string {
  const round = (value: number) => Math.round(value * 100) / 100
  const right = frame.width - (tab.left + tab.width)
  const bottom = frame.height - (tab.top + tab.height)
  return `inset(${round(tab.top)}px ${round(right)}px ${round(bottom)}px ${round(tab.left)}px)`
}

// 真的索引条与反白副本画同一张脸，位置才对得齐
function TabFace({ source }: { source: SourceSummary }) {
  return (
    <>
      <SourceMark adapter={source.adapter} hole="var(--tab-hole)" className="source-tab-icon" />
      <span className="source-tab-body">
        <span className="source-tab-name" lang={latinLang(source.name)}>{source.name}</span>
        {STATE_LINES[source.state] ? <span className="source-tab-state">{STATE_LINES[source.state]}</span> : null}
      </span>
    </>
  )
}

export type SourceTabsProps = {
  sources: SourceSummary[]
  activeId: string
  onSelect: (id: string) => void
  children: (source: SourceSummary) => React.ReactNode
}

export default function SourceTabs({ sources, activeId, onSelect, children }: SourceTabsProps) {
  const frameRef = useRef<HTMLDivElement>(null)
  const listRef = useRef<HTMLDivElement>(null)
  const [clip, setClip] = useState<string | null>(null)
  // 首次渲染的面板不做换入动画，读者切过一次之后新挂上的面板才做
  const [switched, setSwitched] = useState(false)

  useLayoutEffect(() => {
    const frame = frameRef.current
    const list = listRef.current
    if (!frame || !list) return
    let alive = true

    function measure() {
      if (!alive || !frame || !list) return
      const tab = list.querySelector<HTMLElement>('[role="tab"][data-state="active"]')
      const box = frame.getBoundingClientRect()
      if (!tab || box.width === 0) {
        setClip(null)
        return
      }
      const rect = tab.getBoundingClientRect()
      setClip(inkInset(box, { left: rect.left - box.left, top: rect.top - box.top, width: rect.width, height: rect.height }))
    }

    measure()
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(measure)
    observer?.observe(frame)
    // 网页字体到了，来源名的宽度会变（换行时连高度也变）：再量一次
    document.fonts?.ready.then(measure).catch(() => {})
    return () => {
      alive = false
      observer?.disconnect()
    }
  }, [activeId, sources])

  function select(id: string) {
    setSwitched(true)
    onSelect(id)
  }

  return (
    <Tabs.Root value={activeId} onValueChange={select}>
      <div className="source-tabs-frame" ref={frameRef} data-ink={clip ? '' : undefined}>
        {/* 不覆盖 tabIndex：Radix 的 roving focus 让整条索引占 Tab 序列里的一站（进来落在当前源），
            「返回来源目录」的锚点也靠这一站能聚焦。写成 -1 会把整条索引踢出 Tab 序列。 */}
        <Tabs.List ref={listRef} id="source-directory" className="source-tabs" aria-label="来源">
          {sources.map((source) => (
            <Tabs.Trigger key={source.id} value={source.id} className="source-tab">
              <TabFace source={source} />
            </Tabs.Trigger>
          ))}
        </Tabs.List>
        {clip ? (
          <div className="source-tabs source-tabs-ink" aria-hidden="true" inert style={{ clipPath: clip }}>
            {sources.map((source) => (
              <span key={source.id} className="source-tab" data-state="active">
                <TabFace source={source} />
              </span>
            ))}
          </div>
        ) : null}
      </div>

      {/* 每个源都摆一个面板，好让每条 trigger 的 aria-controls 指得到自己的 tabpanel；
          非当前的面板 Radix 自己会卸载，所以列多少个源都不多渲染一条条目。 */}
      {sources.map((source) => (
        <Tabs.Content key={source.id} value={source.id} className="source-panel" data-switched={switched ? '' : undefined}>
          {children(source)}
        </Tabs.Content>
      ))}
    </Tabs.Root>
  )
}
```

- [ ] **Step 4: 跑单测，确认通过（含原有用例）**

Run: `mise exec -- npx vitest run test/frontend/components/SourceTabs.test.tsx test/frontend/pages/DailyShow.test.tsx`
Expected: 全部 PASS。

- [ ] **Step 5: 加墨块样式——`motion.css` 在「M7 弹层」之前插入**

```css
/* ─── M1 墨块平移 ─────────────────────────────────────────────────────── */

/* 副本盖在真的索引条上，用同一组类名排版（含 Q3 的叠边），clip-path 只露出当前项；切换时过渡 clip-path */
.source-tabs-frame { position: relative; }
.source-tabs-ink { position: absolute; inset: 0; pointer-events: none; user-select: none; transition: clip-path var(--dur-2) var(--ease-move); }
.source-tabs-ink .source-tab { background: var(--ink); color: var(--paper); --tab-hole: var(--ink); -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
/* 有副本时真的当前项不再自己反白，墨块由副本画——不然目的地一开始就是墨色，看不到滑动 */
.source-tabs-frame[data-ink] > .source-tabs:not(.source-tabs-ink) > .source-tab[data-state="active"] { background: transparent; color: var(--ink); --tab-hole: var(--paper); }
.source-tabs-frame[data-ink] > .source-tabs:not(.source-tabs-ink) > .source-tab[data-state="active"] .source-tab-state { color: var(--ink2); opacity: 1; }
/* 焦点框画在当前项外面：副本只裁到当前项的矩形，盖不住它 */
.source-tabs-frame[data-ink] > .source-tabs:not(.source-tabs-ink) > .source-tab[data-state="active"]:focus-visible { outline: 2px solid var(--ink); outline-offset: 2px; }
/* 新来源的列表淡入并上移 6px */
.source-panel[data-switched] { animation: lp-rise var(--dur-2) var(--ease-out); }
/* 高对比模式下背景都被系统色换掉，副本没有意义；当前项靠 tokens.css 里的系统色描边区分 */
@media (forced-colors: active) { .source-tabs-ink { display: none; } }
```

- [ ] **Step 6: 写失败的系统测试**

新建 `test/system/motion_test.rb`：

```ruby
require "application_system_test_case"

# 动效（设计说明 2026-10-14 第 4.4 节）里要在真页面上量的部分
class MotionTest < ApplicationSystemTestCase
  setup do
    sign_in_with_browser(users(:drew))
  end

  test "M1 墨块跟着当前来源：副本的裁切与当前项重合，切换后滑到新来源" do
    visit daily_issue_path("2026-09-08")
    assert_selector ".source-tabs-frame[data-ink]"
    assert_ink_on sources(:hn).name

    find(".source-tabs:not(.source-tabs-ink)").click_on sources(:hackaday).name
    assert_ink_on sources(:hackaday).name
  end

  test "M1 连点两个来源，墨块最后停在第二个上" do
    visit daily_issue_path("2026-09-08")

    find(".source-tabs:not(.source-tabs-ink)").click_on sources(:github).name
    find(".source-tabs:not(.source-tabs-ink)").click_on sources(:hackaday).name
    assert_ink_on sources(:hackaday).name
  end

  test "M1 手机宽度同样对齐" do
    with_viewport(375, 812) do
      visit daily_issue_path("2026-09-08")
      find(".source-tabs:not(.source-tabs-ink)").click_on sources(:github).name
      assert_ink_on sources(:github).name
    end
  end

  private
    # 等过渡跑完，再比副本露出的矩形（inline style 里设的 inset）与当前项的矩形
    def assert_ink_on(name)
      wait_until do
        evaluate_script(<<~JS)
          (() => {
            const frame = document.querySelector('.source-tabs-frame').getBoundingClientRect()
            const tab = [...document.querySelectorAll('.source-tabs:not(.source-tabs-ink) [role="tab"]')].find((t) => t.textContent.includes(#{name.to_json}))
            const ink = document.querySelector('.source-tabs-ink')
            if (!tab || !ink || tab.getAttribute('aria-selected') !== 'true' || ink.getAnimations().length) return false
            const values = ink.style.clipPath.match(/inset\\(([^)]*)\\)/)[1].split(/\\s+/).map(parseFloat)
            const [top, right = top, bottom = top, left = right] = values
            const r = tab.getBoundingClientRect()
            const near = (a, b) => Math.abs(a - b) <= 1
            return near(left, r.left - frame.left) && near(top, r.top - frame.top) && near(frame.width - right, r.right - frame.left) && near(frame.height - bottom, r.bottom - frame.top)
          })()
        JS
      end
    end

    def with_viewport(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      yield
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
end
```

- [ ] **Step 7: 改 `reading_test` 的选择器**

副本也带 `source-tabs` 类（为了与真的索引条同一套排版），`find(".source-tabs")` 会匹配到两个元素。`test/system/reading_test.rb` 第 28 行与第 46 行的 `find(".source-tabs").click_on source.name` 都改成：

```ruby
    find(".source-tabs:not(.source-tabs-ink)").click_on source.name
```

- [ ] **Step 8: 构建测试包并跑系统测试**

Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/system/motion_test.rb test/system/reading_test.rb`
Expected: 全部 PASS（副本是 `aria-hidden`、`inert` 的 span，`click_on` 只找链接与按钮，碰不到它）。

- [ ] **Step 9: 目测并逐帧检查**

内置浏览器打开最新日刊，在控制台跑 `document.getAnimations().forEach((a) => a.playbackRate = 0.1)` 后切来源，截两三张中间帧：墨块里的字是纸色、块外是墨色、边线没有错位。

- [ ] **Step 10: 提交**

```bash
git add app/frontend/components/SourceTabs.tsx app/frontend/styles/motion.css test/frontend/components/SourceTabs.test.tsx test/system/motion_test.rb test/system/reading_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "动效：切来源时墨块平移，新来源的列表淡入" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 盖章（M3）

**Files:**
- Modify: `app/frontend/components/FavoriteButton.tsx`
- Modify: `app/frontend/styles/motion.css`
- Test: `test/frontend/components/FavoriteButton.test.tsx`

**Interfaces:**
- Consumes: Task 5 的令牌。
- Produces: 书签按钮内两层 `span.favorite-line` 与 `span.favorite-ink`（都 `aria-hidden`）；`data-stamp` 只在点「收藏」那一下出现。

- [ ] **Step 1: 写失败的单测**

`test/frontend/components/FavoriteButton.test.tsx` 顶部 import 把 `fireEvent` 加进 `@testing-library/react` 的导入，文件末尾加：

```tsx
describe('盖章（M3）', () => {
  it('点「收藏」那一下带 data-stamp，动画结束就去掉', async () => {
    stubFetch(ok({ url_hash: HASH }))
    const user = userEvent.setup()
    mount()

    const button = screen.getByRole('button', { name: ADD })
    await user.click(button)
    expect(button).toHaveAttribute('data-on')
    expect(button).toHaveAttribute('data-stamp')

    fireEvent.animationEnd(button)
    expect(button).not.toHaveAttribute('data-stamp')
  })

  it('取消收藏只退墨，不压', async () => {
    stubFetch(ok({}, 204))
    const user = userEvent.setup()
    mount([HASH])

    const button = screen.getByRole('button', { name: REMOVE })
    await user.click(button)
    expect(button).not.toHaveAttribute('data-on')
    expect(button).not.toHaveAttribute('data-stamp')
  })

  it('页面带进来的已收藏不压：只有点击才盖章', () => {
    mount([HASH])

    expect(screen.getByRole('button', { name: REMOVE })).not.toHaveAttribute('data-stamp')
  })

  it('收藏失败回滚时墨退下，data-stamp 一起去掉', async () => {
    stubFetch(rejected(500))
    const user = userEvent.setup()
    mount()

    const button = screen.getByRole('button', { name: ADD })
    await user.click(button)
    await waitFor(() => expect(button).not.toHaveAttribute('data-on'))
    expect(button).not.toHaveAttribute('data-stamp')
  })

  it('描线与实心两层都对读屏隐藏', () => {
    mount()

    const button = screen.getByRole('button', { name: ADD })
    expect(button.querySelector('.favorite-line')).toHaveAttribute('aria-hidden', 'true')
    expect(button.querySelector('.favorite-ink')).toHaveAttribute('aria-hidden', 'true')
  })
})
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/components/FavoriteButton.test.tsx`
Expected: 新用例 FAIL（没有 `data-stamp`、没有两层）。

- [ ] **Step 3: 改 `FavoriteButton.tsx`**

import 加 `import { useState } from 'react'`；组件主体换成：

```tsx
export default function FavoriteButton({ urlHash, title, itemId, className, ref }: FavoriteButtonProps) {
  const favorites = useFavorites()
  // 盖章（设计 skill「动效」M3）：只在「收藏」那一下压一下；取消与失败回滚只退墨（data-on 去掉，CSS 过渡）
  const [stamping, setStamping] = useState(false)
  if (!favorites) return null

  const on = favorites.has(urlHash)

  return (
    <button
      ref={ref}
      type="button"
      className={className ? `favorite-button ${className}` : 'favorite-button'}
      data-on={on ? '' : undefined}
      data-stamp={stamping && on ? '' : undefined}
      aria-label={`${on ? '取消收藏' : '收藏'}：${title}`}
      onClick={() => {
        setStamping(!on)
        favorites.toggle({ urlHash, itemId })
      }}
      onAnimationEnd={() => setStamping(false)}
    >
      {/* 描线一层常在；实心那层由 clip-path 从底部涨满（两态靠形状分，D30） */}
      <span className="favorite-line" aria-hidden="true"><Icon name="bookmark" size={18} color="currentColor" /></span>
      <span className="favorite-ink" aria-hidden="true"><Icon name="bookmark" size={18} color="currentColor" /></span>
    </button>
  )
}
```

- [ ] **Step 4: 加样式——`motion.css` 在「M7 弹层」之前插入**

```css
/* ─── M3 盖章 ─────────────────────────────────────────────────────────── */

/* 描线一层常在；实心那层叠在上面，用 clip-path 从底部涨满；收藏的那一下按钮轻压（0.92 → 1） */
.favorite-button { position: relative; }
.favorite-line, .favorite-ink { display: block; }
.favorite-ink { position: absolute; left: 50%; top: 50%; translate: -50% -50%; clip-path: inset(100% 0 0 0); transition: clip-path var(--dur-2) var(--ease-out); }
.favorite-ink svg, .favorite-ink svg path { fill: currentColor; }
.favorite-button[data-on] .favorite-ink { clip-path: inset(0 0 0 0); }
/* tokens.css 里「data-on 时整个 svg 填墨」那条留给旧结构；描线那层不填，墨只由实心层带出来 */
.favorite-button[data-on] .favorite-line svg, .favorite-button[data-on] .favorite-line svg path { fill: none; }
.favorite-button[data-stamp] { animation: lp-press var(--dur-2) var(--ease-out); }
@keyframes lp-press { from { transform: scale(0.92); } }
```

- [ ] **Step 5: 跑，确认通过**

Run: `mise exec -- npx vitest run test/frontend/components/FavoriteButton.test.tsx test/frontend/components/ItemRow.test.tsx test/frontend/pages/FavoritesIndex.test.tsx`
Expected: 全部 PASS。

- [ ] **Step 6: 系统测试回归**

Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/system/favoriting_test.rb`
Expected: 全部 PASS（书签仍是 44 见方）。

- [ ] **Step 7: 目测**

内置浏览器里点一个书签：墨从底部涨满、按钮轻压；再点：墨退下。

- [ ] **Step 8: 提交**

```bash
git add app/frontend/components/FavoriteButton.tsx app/frontend/styles/motion.css test/frontend/components/FavoriteButton.test.tsx
```

```bash
git -c commit.gpgsign=false commit -m "动效：收藏时书签盖章，墨从底部涨满；取消与回滚只退墨" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 翻页与键盘翻页（M2、M8）

**Files:**
- Create: `app/frontend/lib/motion.ts`
- Create: `app/frontend/lib/pageTurn.ts`
- Modify: `app/frontend/entrypoints/application.tsx`（`defaults.visitOptions`）
- Modify: `app/frontend/components/Ctrl.tsx`（`turn` 参数）
- Modify: `app/frontend/components/PageHead.tsx`、`app/frontend/components/Footer.tsx`（给前一期 / 后一期传 `turn`）
- Modify: `app/frontend/pages/Daily/Show.tsx`、`app/frontend/pages/Weekly/Show.tsx`（`useArrowTurns`）
- Modify: `app/frontend/styles/motion.css`
- Modify: `test/frontend/support/inertia.tsx`（Link 替身丢掉 `viewTransition`）
- Test: `test/frontend/lib/pageTurn.test.ts`、`test/system/motion_test.rb`

**Interfaces:**
- Consumes: Task 5 的令牌。
- Produces:
  - `lib/motion.ts`：`export function prefersReducedMotion(): boolean`
  - `lib/pageTurn.ts`：`export type TurnDirection = 'back' | 'forward'`；`export function pageTurn(direction: TurnDirection): false | ((transition: ViewTransition) => void)`；`export function crossfadeFor(href: string, options: VisitOptions): { viewTransition?: VisitOptions['viewTransition'] }`；`export function ignoresArrow(event: KeyboardEvent): boolean`；`export function useArrowTurns(prevHref: string | null, nextHref: string | null): void`
  - `Ctrl` / `Square` 新参数 `turn?: TurnDirection`
  - `<html data-vt>`（过渡进行中）与 `<html data-turn="back|forward">`（有方向时），过渡结束摘掉

- [ ] **Step 1: 改测试替身**

`test/frontend/support/inertia.tsx` 的 `Link` 换成：

```tsx
export function Link({ href, children, preserveState: _preserveState, viewTransition: _viewTransition, ...rest }: React.ComponentProps<'a'> & { preserveState?: boolean; viewTransition?: unknown }) {
  return (
    <a href={href} {...rest}>
      {children}
    </a>
  )
}
```

- [ ] **Step 2: 写失败的单测**

新建 `test/frontend/lib/pageTurn.test.ts`：

```ts
import { renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { crossfadeFor, ignoresArrow, pageTurn, useArrowTurns } from '@/lib/pageTurn'
import { router } from '../support/inertia'

// 翻页（设计说明 2026-10-14 M2、M8）：方向写在 <html data-turn>，过渡进行中有 <html data-vt>，结束就摘掉

function fakeTransition() {
  let finish!: () => void
  const finished = new Promise<void>((resolve) => { finish = resolve })
  return { transition: { finished } as unknown as ViewTransition, finish }
}

function reduceMotion(matches: boolean) {
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
}

afterEach(() => {
  vi.unstubAllGlobals()
  delete document.documentElement.dataset.vt
  delete document.documentElement.dataset.turn
  router.visit.mockClear()
  window.history.replaceState({}, '', '/')
})

describe('pageTurn', () => {
  it('过渡开始时写上方向，结束时摘掉', async () => {
    const { transition, finish } = fakeTransition()
    const callback = pageTurn('back')
    expect(callback).toBeTypeOf('function')

    ;(callback as (t: ViewTransition) => void)(transition)
    expect(document.documentElement.dataset.turn).toBe('back')
    expect(document.documentElement.dataset.vt).toBe('')

    finish()
    await transition.finished
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBeUndefined()
    expect(document.documentElement.dataset.vt).toBeUndefined()
  })

  // 连点两次：第一次的收尾不能摘掉第二次的方向
  it('上一次翻页结束时不摘掉下一次的标记', async () => {
    const first = fakeTransition()
    const second = fakeTransition()
    ;(pageTurn('forward') as (t: ViewTransition) => void)(first.transition)
    ;(pageTurn('forward') as (t: ViewTransition) => void)(second.transition)

    first.finish()
    await first.transition.finished
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBe('forward')

    second.finish()
    await second.transition.finished
    await Promise.resolve()
    expect(document.documentElement.dataset.turn).toBeUndefined()
  })

  it('减少动态效果时不做过渡', () => {
    reduceMotion(true)
    expect(pageTurn('back')).toBe(false)
  })
})

describe('crossfadeFor', () => {
  it('换了路径的 GET 访问淡入淡出', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08')
    expect(crossfadeFor('/weekly/2026-W36', {}).viewTransition).toBeTypeOf('function')
  })

  it('同一路径、保留状态、局部刷新、轮询、预取、非 GET 都不做', () => {
    window.history.replaceState({}, '', '/daily/2026-09-08')
    expect(crossfadeFor('/daily/2026-09-08?source=x', {})).toEqual({})
    expect(crossfadeFor('/weekly', { preserveState: true })).toEqual({})
    expect(crossfadeFor('/weekly', { only: ['issue'] })).toEqual({})
    expect(crossfadeFor('/weekly', { async: true })).toEqual({})
    expect(crossfadeFor('/weekly', { prefetch: true })).toEqual({})
    expect(crossfadeFor('/favorites', { method: 'post' })).toEqual({})
  })

  // Inertia 把这里的返回值盖在访问自带的选项上：前一期 / 后一期自己带了方向，必须原样放过
  it('访问已经带了 viewTransition 就不碰', () => {
    expect(crossfadeFor('/weekly', { viewTransition: false })).toEqual({})
  })

  it('减少动态效果时不做', () => {
    reduceMotion(true)
    expect(crossfadeFor('/weekly', {})).toEqual({})
  })
})

describe('键盘翻页', () => {
  const key = (init: KeyboardEventInit & { key: string }, target: EventTarget = document.body) => {
    const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init })
    Object.defineProperty(event, 'target', { value: target })
    return event
  }

  it('输入框、索引条、菜单、对话框里，按着修饰键或按住不放时不翻', () => {
    const input = document.createElement('input')
    const tablist = document.createElement('div')
    tablist.setAttribute('role', 'tablist')
    const tab = document.createElement('button')
    tablist.appendChild(tab)
    document.body.append(input, tablist)

    expect(ignoresArrow(key({ key: 'ArrowLeft' }, input))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft' }, tab))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft', metaKey: true }))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft', repeat: true }))).toBe(true)
    expect(ignoresArrow(key({ key: 'ArrowLeft' }))).toBe(false)

    input.remove()
    tablist.remove()
  })

  it('← 去前一期，→ 去后一期；没有后一期时 → 不动', () => {
    renderHook(() => useArrowTurns('/daily/2026-09-07', null))

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true, cancelable: true }))
    expect(router.visit).toHaveBeenCalledWith('/daily/2026-09-07', expect.objectContaining({ viewTransition: expect.any(Function) }))

    router.visit.mockClear()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true, cancelable: true }))
    expect(router.visit).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 3: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/lib/pageTurn.test.ts`
Expected: FAIL（模块不存在）。

- [ ] **Step 4: 新建 `lib/motion.ts`**

```ts
// 系统「减少动态效果」：所有动效都看它（设计 skill「动效」）。没有 matchMedia（jsdom）就当没开
export function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true
}
```

- [ ] **Step 5: 新建 `lib/pageTurn.ts`**

```ts
import { router } from '@inertiajs/react'
import type { VisitOptions } from '@inertiajs/core'
import { useEffect } from 'react'

import { prefersReducedMotion } from '@/lib/motion'

// 翻页（设计 skill「动效」M2、M8，PRD D34）。前一期 / 后一期是有方向的翻页：报头不动，正文从左或从右滑入；
// 其余换页面的整页跳转只让正文淡入淡出。用浏览器原生的 View Transitions，经 Inertia 的 viewTransition 选项接进来。
//
// 过渡进行中给 <html> 打上 data-vt（motion.css 只在这时给报头、正文、期头大字起 view-transition-name）：
// 常驻的 view-transition-name 会让元素自成层叠上下文，报头的头像菜单会被正文里定位的元素盖住，周刊配图的
// 正片叠底也会失效。Inertia 调 startViewTransition 后立刻同步调这里的回调，旧画面在下一帧才截，标记来得及。
// 方向写在 data-turn。不支持的浏览器、减少动态效果时直接切换。

export type TurnDirection = 'back' | 'forward'

// 最近一次过渡的记号：连点两次时，前一次的收尾不能摘掉后一次的标记
let active: object | null = null

function track(transition: ViewTransition, direction: TurnDirection | null) {
  const token = {}
  active = token
  const root = document.documentElement
  root.dataset.vt = ''
  if (direction) root.dataset.turn = direction
  else delete root.dataset.turn
  transition.finished.finally(() => {
    if (active !== token) return
    active = null
    delete root.dataset.vt
    delete root.dataset.turn
  })
}

export function pageTurn(direction: TurnDirection): false | ((transition: ViewTransition) => void) {
  if (prefersReducedMotion()) return false
  return (transition) => track(transition, direction)
}

// 其余整页跳转（换了路径的 GET 访问）：正文淡入淡出。保留状态的访问、局部刷新、轮询、预取、表单提交不做，
// 已经带了 viewTransition 的访问（前一期 / 后一期）原样放过。Inertia 把这里的返回值盖在访问自带的选项上，
// 所以不该管的时候必须返回空对象，不能写 viewTransition: false。
export function crossfadeFor(href: string, options: VisitOptions): { viewTransition?: VisitOptions['viewTransition'] } {
  if (options.viewTransition !== undefined) return {}
  if ((options.method ?? 'get') !== 'get') return {}
  if (options.preserveState || options.async || options.prefetch || (options.only?.length ?? 0) > 0) return {}
  if (prefersReducedMotion()) return {}
  if (new URL(href, window.location.href).pathname === window.location.pathname) return {}
  return { viewTransition: (transition: ViewTransition) => track(transition, null) }
}

// 键盘翻页（M8）：焦点在输入框、索引条、菜单、对话框里，按着修饰键，或按住不放（repeat）时不翻
const IGNORE_WITHIN = '[role="tablist"], [role="menu"], [role="dialog"], [role="listbox"], [role="slider"], [contenteditable=""], [contenteditable="true"]'

export function ignoresArrow(event: KeyboardEvent): boolean {
  if (event.defaultPrevented || event.repeat || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return true
  const target = event.target instanceof Element ? event.target : null
  if (target && (target.matches('input, textarea, select') || target.closest(IGNORE_WITHIN))) return true
  return document.querySelector('.dialog-shade') !== null
}

export function useArrowTurns(prevHref: string | null, nextHref: string | null): void {
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return
      if (ignoresArrow(event)) return
      const back = event.key === 'ArrowLeft'
      const href = back ? prevHref : nextHref
      if (!href) return
      event.preventDefault()
      router.visit(href, { viewTransition: pageTurn(back ? 'back' : 'forward') })
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [prevHref, nextHref])
}
```

- [ ] **Step 6: 跑单测，确认通过**

Run: `mise exec -- npx vitest run test/frontend/lib/pageTurn.test.ts`
Expected: 全部 PASS。

- [ ] **Step 7: 接进 Inertia、按钮与页面**

`application.tsx`：import 加 `import { crossfadeFor } from '@/lib/pageTurn'`，`defaults.visitOptions` 换成：

```ts
    visitOptions: (href, options) => {
      return { queryStringArrayFormat: "brackets", ...crossfadeFor(href, options) }
    },
```

`Ctrl.tsx`：import 加 `import { pageTurn, type TurnDirection } from '@/lib/pageTurn'`；类型与两个组件改成：

```tsx
export type CtrlProps = {
  href: string | null
  label: string
  icon?: IconName
  side?: 'left' | 'right'
  // 前一期 / 后一期：带方向的翻页（设计 skill「动效」M2），并告诉读屏 ← / → 也能翻（M8）
  turn?: TurnDirection
}

const KEYS: Record<TurnDirection, string> = { back: 'ArrowLeft', forward: 'ArrowRight' }
```

`Ctrl` 的可点分支：

```tsx
  return (
    <Link className="ctrl" href={href} viewTransition={turn ? pageTurn(turn) : undefined} aria-keyshortcuts={turn ? KEYS[turn] : undefined}>
      {body}
    </Link>
  )
```

`Square` 签名改成 `({ href, label, icon, turn }: { href: string | null; label: string; icon: IconName; turn?: TurnDirection })`，可点分支：

```tsx
  return (
    <Link className="ctrl ctrl-square" href={href} aria-label={label} viewTransition={turn ? pageTurn(turn) : undefined} aria-keyshortcuts={turn ? KEYS[turn] : undefined}>
      <Icon name={icon} size={18} color="currentColor" />
    </Link>
  )
```

`PageHead.tsx`：桌面三个 `Ctrl` 里前一期加 `turn="back"`、后一期加 `turn="forward"`；手机三个 `Square` 同样。`Footer.tsx`：两个 `Ctrl` 同样加 `turn="back"` / `turn="forward"`。

`pages/Daily/Show.tsx`：import 加 `import { useArrowTurns } from '@/lib/pageTurn'`，`Show` 里 `usePolling(...)` 之后加：

```tsx
  useArrowTurns(issue.prev_key ? dailyHref(issue.prev_key) : null, issue.next_key ? dailyHref(issue.next_key) : null)
```

`pages/Weekly/Show.tsx`：import 同上，`Show` 里 `useScrollToHash(issue.period_key)` 之后加：

```tsx
  useArrowTurns(issue.prev_key ? weeklyHref(issue.prev_key) : null, issue.next_key ? weeklyHref(issue.next_key) : null)
```

- [ ] **Step 8: 加过渡样式——`motion.css` 在「M7 弹层」之前插入**

```css
/* ─── M2 翻页 ─────────────────────────────────────────────────────────── */

/* 名字只在过渡进行中起（lib/pageTurn.ts 的 data-vt）：常驻会让元素自成层叠上下文 */
html[data-vt] .masthead { view-transition-name: masthead; }
html[data-vt] #main-content { view-transition-name: page; }
html[data-vt] .issue-head-date { view-transition-name: issue-date; }
::view-transition-group(*) { animation-duration: var(--dur-2); animation-timing-function: var(--ease-out); }
/* 报头不动 */
::view-transition-old(masthead), ::view-transition-new(masthead) { animation: none; }
/* 前一期：新页从左边进、旧页向右出；后一期相反。位移 24px 加淡入淡出 */
html[data-turn="back"]::view-transition-old(page) { animation: lp-turn-out-right var(--dur-3) var(--ease-move) both; }
html[data-turn="back"]::view-transition-new(page) { animation: lp-turn-in-left var(--dur-3) var(--ease-move) both; }
html[data-turn="forward"]::view-transition-old(page) { animation: lp-turn-out-left var(--dur-3) var(--ease-move) both; }
html[data-turn="forward"]::view-transition-new(page) { animation: lp-turn-in-right var(--dur-3) var(--ease-move) both; }
@keyframes lp-turn-out-right { to { opacity: 0; transform: translateX(24px); } }
@keyframes lp-turn-out-left { to { opacity: 0; transform: translateX(-24px); } }
@keyframes lp-turn-in-left { from { opacity: 0; transform: translateX(-24px); } }
@keyframes lp-turn-in-right { from { opacity: 0; transform: translateX(24px); } }
```

并把文件末尾「减少动态效果」那段里加一条：

```css
  ::view-transition-group(*), ::view-transition-old(*), ::view-transition-new(*) { animation: none !important; }
```

- [ ] **Step 9: 写失败的系统测试**

加到 `test/system/motion_test.rb` 的 `private` 之前：

```ruby
  test "M8 ← 到前一期，→ 回到后一期；最新一期按 → 不动；输入框里按 ← 不翻" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    visit daily_issue_path("2026-09-08")

    find("body").send_keys(:right)
    assert_current_path daily_issue_path("2026-09-08")

    find("body").send_keys(:left)
    assert_current_path daily_issue_path("2026-09-07")
    assert_no_selector "html[data-vt]", visible: :all, wait: 2

    find("body").send_keys(:right)
    assert_current_path daily_issue_path("2026-09-08")

    find("a[aria-label='搜索']").click
    find("input[type='search']").send_keys(:left)
    assert_current_path search_path
  end

  test "M2 前一期按钮带方向与键盘提示" do
    Issue.create!(kind: "daily", period_key: "2026-09-07", state: "empty", generation_started_at: Time.utc(2026, 9, 6, 22), published_at: Time.utc(2026, 9, 6, 22, 5), source_states: {})
    visit daily_issue_path("2026-09-08")

    assert_selector ".issue-nav a.ctrl[aria-keyshortcuts='ArrowLeft']", text: "前一期"
    find(".issue-nav a.ctrl", text: "前一期").click
    assert_current_path daily_issue_path("2026-09-07")
  end
```

- [ ] **Step 10: 构建并跑系统测试**

Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/system/motion_test.rb test/system/reading_test.rb test/system/searching_test.rb`
Expected: 全部 PASS（`reading_test` 的后退前进、来源保留不受影响；搜索框是 `input[type="search"].search-input`）。

- [ ] **Step 11: 跑全部前端单测与类型检查**

Run: `mise exec -- npm run check`
Run: `mise exec -- npm test`
Expected: 全部 PASS。

- [ ] **Step 12: 目测翻页**

内置浏览器：日刊页点「后一期」「前一期」、按 ← / →：报头不动，正文向对应方向滑；从页脚的前后期按钮翻，新页落在顶部；从归档进某一期是淡入淡出；切来源没有过渡。周刊详情页（若有相邻两期）同样。

- [ ] **Step 13: 提交**

```bash
git add app/frontend/lib/motion.ts app/frontend/lib/pageTurn.ts app/frontend/entrypoints/application.tsx app/frontend/components/Ctrl.tsx app/frontend/components/PageHead.tsx app/frontend/components/Footer.tsx app/frontend/pages/Daily/Show.tsx app/frontend/pages/Weekly/Show.tsx app/frontend/styles/motion.css test/frontend/support/inertia.tsx test/frontend/lib/pageTurn.test.ts test/system/motion_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "动效：前一期 / 后一期像翻页，← / → 也能翻；其余整页跳转淡入淡出" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: 开场（M5）

**Files:**
- Modify: `app/frontend/lib/motion.ts`（加 `markFirstLoad`）
- Modify: `app/frontend/entrypoints/application.tsx`
- Modify: `app/frontend/styles/motion.css`
- Test: `test/frontend/lib/motion.test.ts`、`test/system/motion_test.rb`

**Interfaces:**
- Consumes: Task 8 的 `prefersReducedMotion`；Task 5 的关键帧与令牌；Task 6 的 `.source-tabs-frame`、`.source-panel`。
- Produces: `export function markFirstLoad(storage?: Storage | null): boolean`；`<html data-first-load>`（≤ 800ms，Inertia 访问开始时也摘）。

- [ ] **Step 1: 写失败的单测**

新建 `test/frontend/lib/motion.test.ts`：

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { markFirstLoad } from '@/lib/motion'
import { emitRouterEvent } from '../support/inertia'

// 开场（设计说明 2026-10-14 M5）：每个标签页会话第一次整页加载时播一次

function memoryStorage(): Storage {
  const map = new Map<string, string>()
  return {
    getItem: (key) => map.get(key) ?? null,
    setItem: (key, value) => void map.set(key, value),
    removeItem: (key) => void map.delete(key),
    clear: () => map.clear(),
    key: () => null,
    get length() { return map.size },
  }
}

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
  delete document.documentElement.dataset.firstLoad
})

describe('markFirstLoad', () => {
  it('会话里第一次打上标记，第二次不打', () => {
    const storage = memoryStorage()

    expect(markFirstLoad(storage)).toBe(true)
    expect(document.documentElement.dataset.firstLoad).toBe('')
    delete document.documentElement.dataset.firstLoad

    expect(markFirstLoad(storage)).toBe(false)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('800ms 后摘掉标记', () => {
    markFirstLoad(memoryStorage())

    vi.advanceTimersByTime(799)
    expect(document.documentElement.dataset.firstLoad).toBe('')
    vi.advanceTimersByTime(1)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('站内访问一开始就摘掉，新页面不接着播', () => {
    markFirstLoad(memoryStorage())

    emitRouterEvent('start')
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('减少动态效果时不播', () => {
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }))

    expect(markFirstLoad(memoryStorage())).toBe(false)
    expect(document.documentElement.dataset.firstLoad).toBeUndefined()
  })

  it('sessionStorage 不可用（隐私模式抛错）时不播', () => {
    const broken = { ...memoryStorage(), getItem: () => { throw new Error('denied') } } as Storage

    expect(markFirstLoad(broken)).toBe(false)
    expect(markFirstLoad(null)).toBe(false)
  })
})
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/lib/motion.test.ts`
Expected: FAIL（`markFirstLoad` 不存在）。

- [ ] **Step 3: 实现——`lib/motion.ts` 追加**

文件顶部加 `import { router } from '@inertiajs/react'`，末尾加：

```ts
// 开场（M5）：每个标签页会话第一次整页加载时，期头大字、2px 底线、索引条、列表依次出现（motion.css 认 html[data-first-load]）。
// 同一会话里刷新、站内跳转、后退缓存恢复（脚本不重跑）都不播；减少动态效果、sessionStorage 不可用时也不播。
// 动画总长 ≤ 600ms，800ms 后摘掉标记；站内访问一开始也摘，免得新页面接着播。
const OPENED = 'lowpass:opened'
const FIRST_LOAD_MS = 800

export function markFirstLoad(storage: Storage | null = sessionStorageOrNull()): boolean {
  if (!storage || prefersReducedMotion()) return false
  try {
    if (storage.getItem(OPENED)) return false
    storage.setItem(OPENED, '1')
  } catch {
    return false
  }

  const root = document.documentElement
  root.dataset.firstLoad = ''
  const clear = () => {
    delete root.dataset.firstLoad
    off()
  }
  const off = router.on('start', clear)
  window.setTimeout(clear, FIRST_LOAD_MS)
  return true
}

function sessionStorageOrNull(): Storage | null {
  try {
    return window.sessionStorage
  } catch {
    return null
  }
}
```

- [ ] **Step 4: 跑单测，确认通过**

Run: `mise exec -- npx vitest run test/frontend/lib/motion.test.ts test/frontend/lib/pageTurn.test.ts`
Expected: 全部 PASS。

- [ ] **Step 5: 接进入口与样式**

`application.tsx`：import 加 `import { markFirstLoad } from '@/lib/motion'`，`focusMainOnNavigate()` 之后加一行 `markFirstLoad()`。

`motion.css` 在「M7 弹层」之前插入：

```css
/* ─── M5 开场 ─────────────────────────────────────────────────────────── */

/* 每个标签页会话第一次整页加载：期头大字自下而上露出并上移 8px（360ms）；2px 底线从左画出（延迟 60ms）；
   索引条 / 搜索框淡入（延迟 120ms）；列表最后淡入（延迟 180ms）。总长 420ms。只动 clip-path、transform、opacity。
   底线动画期间由伪元素代画：标记摘掉后原来的 border 回来，像素一致。 */
@keyframes lp-reveal { from { clip-path: inset(100% 0 0 0); transform: translateY(8px); } to { clip-path: inset(0 0 0 0); transform: none; } }
@keyframes lp-draw { from { transform: scaleX(0); } }
html[data-first-load] .page-head .issue-head-date { animation: lp-reveal var(--dur-3) var(--ease-out) both; }
html[data-first-load] .page-head { position: relative; border-bottom-color: transparent; }
html[data-first-load] .page-head::after {
  content: ""; position: absolute; left: 0; right: 0; bottom: -2px; height: 2px; background: var(--ink);
  transform-origin: 0 50%; animation: lp-draw var(--dur-3) var(--ease-move) 60ms both;
}
html[data-first-load] .source-tabs-frame, html[data-first-load] .search-head, html[data-first-load] .source-band {
  animation: lp-rise var(--dur-2) var(--ease-out) 120ms both;
}
html[data-first-load] .source-panel, html[data-first-load] .archive-list, html[data-first-load] .weekly-directory,
html[data-first-load] #main-content section, html[data-first-load] .search-entry, html[data-first-load] .search-count,
html[data-first-load] .search-row, html[data-first-load] .settings-rows, html[data-first-load] #main-content > .issue-body {
  animation: lp-fade var(--dur-2) var(--ease-out) 180ms both;
}
```

- [ ] **Step 6: 写失败的系统测试**

加到 `test/system/motion_test.rb` 的 `private` 之前：

```ruby
  test "M5 会话第一次打开播开场，刷新不重播，版面不跳" do
    execute_script("sessionStorage.clear()")
    visit daily_issue_path("2026-09-08")
    assert evaluate_script("document.documentElement.hasAttribute('data-first-load')"), "第一次打开应有开场标记"

    cls = evaluate_async_script(<<~JS)
      const done = arguments[0]
      let total = 0
      new PerformanceObserver((list) => { for (const entry of list.getEntries()) total += entry.value }).observe({ type: 'layout-shift', buffered: true })
      setTimeout(() => done(total), 900)
    JS
    assert_equal 0, cls

    assert_not evaluate_script("document.documentElement.hasAttribute('data-first-load')"), "800ms 后应摘掉"
    refresh
    assert_not evaluate_script("document.documentElement.hasAttribute('data-first-load')"), "同一会话刷新不重播"
  end
```

- [ ] **Step 7: 构建并跑**

Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/system/motion_test.rb`
Expected: 全部 PASS。

- [ ] **Step 8: 目测并量 LCP 增量**

本地：清掉 sessionStorage 后打开最新日刊，录屏或逐帧截图看顺序；用 `PerformanceObserver` 的 `largest-contentful-paint` 分别量「有开场」与「`sessionStorage` 已有标记」两次加载，增量 ≤ 250ms，记进 Task 16 的轮次笔记。

- [ ] **Step 9: 提交**

```bash
git add app/frontend/lib/motion.ts app/frontend/entrypoints/application.tsx app/frontend/styles/motion.css test/frontend/lib/motion.test.ts test/system/motion_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "动效：每个会话第一次打开时的出刊顺序（期头、底线、索引条、列表）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: 周刊——「翻开的书」与配图叠底（Q1 图形、C3、插图之一）

**Files:**
- Modify: `app/frontend/components/Illustration.tsx`（新增并导出 `OpenBook`，`MARKS.ruanyf_weekly` 指向它）
- Modify: `app/frontend/pages/Weekly/Show.tsx`（横带图标换成 `OpenBook`）
- Modify: `app/frontend/components/Icon.tsx`（`book-open` 不再有人用就删掉这一项与 import）
- Modify: `app/frontend/styles/tokens.css`（品质提升段末尾追加）
- Test: `test/frontend/pages/WeeklyShow.test.tsx`、`test/system/design_rules_test.rb`

**Interfaces:**
- Consumes: Task 3 的 Q1（横带纸色）。
- Produces: `export function OpenBook({ hole, className }: SourceMarkProps): React.ReactElement`；横带里的 `svg.source-band-mark`。

- [ ] **Step 1: 写失败的单测**

加到 `test/frontend/pages/WeeklyShow.test.tsx` 末尾：

```tsx
it('来源横带用「翻开的书」木刻图形，对读屏隐藏', () => {
  const { container } = show()

  const mark = container.querySelector('.source-band svg.source-band-mark')
  expect(mark).not.toBeNull()
  expect(mark).toHaveAttribute('aria-hidden', 'true')
})
```

（`show()` 是该文件已有的渲染辅助函数，默认带一节阮一峰周刊。）

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/pages/WeeklyShow.test.tsx`
Expected: 新用例 FAIL。

- [ ] **Step 3: 画「翻开的书」**

`Illustration.tsx` 在 `Solder` 之后加：

```tsx
// 翻开的书：周刊的来源图形（阮一峰周刊与以后的周刊源都用它）。左页几行字，右页一块排线像版面上的图，下面是书口。
// 与其余三幅同一套笔法：2px 墨线、圆头、45° 排线；反白时挖空处填墨（hole）。
export function OpenBook({ hole, className }: SourceMarkProps) {
  return (
    <svg viewBox="0 0 120 78" className={className} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M60 18 C 48 12 30 10 14 13 L 14 64 C 30 61 48 63 60 70 Z" fill={hole} />
      <path d="M60 18 C 72 12 90 10 106 13 L 106 64 C 90 61 72 63 60 70 Z" fill={hole} />
      <line x1="60" y1="18" x2="60" y2="70" />
      <path d="M22 24 C 32 22 42 23 52 26" strokeWidth={1.4} />
      <path d="M22 32 C 32 30 42 31 52 34" strokeWidth={1.4} />
      <path d="M22 40 C 32 38 42 39 52 42" strokeWidth={1.4} />
      <path d="M22 48 C 30 46.5 36 47 42 48.5" strokeWidth={1.4} />
      <rect x="68" y="24" width="30" height="26" fill={hole} strokeWidth={1.4} />
      {hatch(70, 26, 26, 22, 5)}
      <path d="M14 64 C 30 61 48 63 60 70 C 72 63 90 61 106 64 L 106 68 C 90 65 72 67 60 74 C 48 67 30 65 14 68 Z" strokeWidth={1.4} />
    </svg>
  )
}
```

`MARKS` 里 `ruanyf_weekly: Solder,` 改成 `ruanyf_weekly: OpenBook,`，并把那段注释「Task 18 做周刊页时再给它一幅自己的」改成「周刊源用「翻开的书」（2026-10-14）」。

- [ ] **Step 4: 横带换图形**

`Weekly/Show.tsx`：import 加 `import { OpenBook } from '@/components/Illustration'`；`SourceBand` 里 `<Icon name="book-open" size={28} color="currentColor" />` 换成：

```tsx
        <OpenBook hole="var(--ink)" className="source-band-mark" />
```

`Icon` 在这个文件里还用于原文外链的箭头，import 保留。`book-open` 原先只有横带用，换掉后从 `Icon.tsx` 的 `ICONS` 里删掉 `'book-open': BookOpen,` 这一项，并从顶部的 lucide import 里删掉 `BookOpen`（`Icon.test.tsx` 不涉及它）。

- [ ] **Step 5: 跑单测，确认通过**

Run: `mise exec -- npx vitest run test/frontend/pages/WeeklyShow.test.tsx test/frontend/components/Icon.test.tsx`
Expected: 全部 PASS。

- [ ] **Step 6: 写失败的样式测试**

加到 `test/system/design_rules_test.rb` 的 `private` 之前：

```ruby
  test "C3 周刊配图正片叠底；横带图形 52×34，手机 37×24" do
    render_fragment(%(<div class="source-band"><svg class="source-band-mark" viewBox="0 0 120 78"></svg></div><img class="item-media-image" alt="">))

    assert_equal "multiply", style(".item-media-image", "mix-blend-mode")
    assert_equal [ 52, 34 ], evaluate_script("(() => { const r = document.querySelector('.source-band-mark').getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height)] })()")

    render_fragment(%(<div class="source-band"><svg class="source-band-mark" viewBox="0 0 120 78"></svg></div>), width: 375, height: 812)
    assert_equal [ 37, 24 ], evaluate_script("(() => { const r = document.querySelector('.source-band-mark').getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height)] })()")
  end
```

- [ ] **Step 7: 实现——`tokens.css` 品质提升段末尾追加**

```css
/* Q1 横带图形「翻开的书」：纸色线、挖空填墨，比例 120:78 */
.source-band-mark { flex: none; display: block; width: 52px; height: 34px; }
@media (max-width: 767px) { .source-band-mark { width: 37px; height: 24px; } }

/* C3（O2 选 a）：周刊配图正片叠底压进纸面，白处呈纸色，像印在纸上；打印时恢复原样（print.css） */
.item-media-image { mix-blend-mode: multiply; }
```

- [ ] **Step 8: 跑，确认通过**

Run: `mise exec -- bin/rails test test/system/design_rules_test.rb`
Expected: 全部 PASS。

- [ ] **Step 9: 目测周刊详情**

内置浏览器打开样本周刊（开发库里的 2026-W42）：横带左端是纸色的翻开的书；配图的白底与纸面融成一体；照片不发灰。

- [ ] **Step 10: 提交**

```bash
git add app/frontend/components/Illustration.tsx app/frontend/pages/Weekly/Show.tsx app/frontend/components/Icon.tsx app/frontend/styles/tokens.css test/frontend/pages/WeeklyShow.test.tsx test/system/design_rules_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "周刊：来源横带换成木刻「翻开的书」，配图正片叠底压进纸面" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: 错误页——「缺页」（C2、插图之二）

**Files:**
- Modify: `app/frontend/components/Illustration.tsx`（新增并导出 `MissingPage`）
- Modify: `app/frontend/pages/Errors/NotFound.tsx`、`app/frontend/pages/Errors/Forbidden.tsx`
- Modify: `app/frontend/styles/tokens.css`（品质提升段末尾追加）
- Create: `test/frontend/pages/ErrorPages.test.tsx`

**Interfaces:**
- Consumes: 无。
- Produces: `export function MissingPage({ className }: { className?: string }): React.ReactElement`；错误页 DOM：`.source-state.error-state > .error-art > svg` + `.error-copy > h1.state-line + a.ctrl`。

- [ ] **Step 1: 写失败的单测**

新建 `test/frontend/pages/ErrorPages.test.tsx`：

```tsx
import { render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it } from 'vitest'

import { DAILY_LATEST } from '@/lib/paths'
import Forbidden from '@/pages/Errors/Forbidden'
import NotFound from '@/pages/Errors/NotFound'
import { setPageProps } from '../support/inertia'

// 404 / 403（附录 B）：与栏级失败态同一装置——1px 框里一幅木刻「缺页」，一句事实，一个动作（设计说明 2026-10-14 C2）

beforeEach(() => {
  setPageProps({ daily_time: '06:00', latest_weekly_key: null })
})

describe.each([
  ['404', NotFound, '这一页不存在。'],
  ['403', Forbidden, '你没有权限访问这个页面。'],
])('%s', (_code, Page, sentence) => {
  it('缺页插图在 1px 框里、对读屏隐藏；一句事实；一个回首页的动作', () => {
    const { container } = render(<Page />)

    expect(screen.getByRole('heading', { level: 1, name: sentence })).toBeInTheDocument()
    expect(container.querySelector('.error-art svg')).toHaveAttribute('aria-hidden', 'true')
    expect(screen.getByRole('link', { name: '回到首页' })).toHaveAttribute('href', DAILY_LATEST)
  })
})
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/pages/ErrorPages.test.tsx`
Expected: FAIL（没有 `.error-art`）。

- [ ] **Step 3: 画「缺页」**

`Illustration.tsx` 在 `Sunrise` 之后加：

```tsx
// 缺页：一张对折的报纸，右页正中被裁去一块（虚线是裁口），缺口里是 45° 排线的阴影。404 与 403 用（viewBox 同日出，260×138）。
export function MissingPage({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 260 138" className={className} fill="none" stroke="var(--ink)" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M30 20 L 128 14 L 128 124 L 30 118 Z" fill="var(--paper)" />
      <path d="M132 14 L 230 20 L 230 118 L 132 124 Z" fill="var(--paper)" />
      <line x1="130" y1="12" x2="130" y2="126" strokeWidth={1} />
      <line x1="40" y1="30" x2="118" y2="26" strokeWidth={4} />
      {[44, 54, 64, 74, 84, 94, 104].map((y, index) => (
        <line key={y} x1="40" y1={y - index * 0.4} x2={index % 3 === 2 ? 96 : 118} y2={y - index * 0.4 - 3} strokeWidth={1} />
      ))}
      <line x1="146" y1="28" x2="218" y2="31" strokeWidth={1} />
      <rect x="150" y="40" width="62" height="48" fill="var(--paper)" strokeDasharray="4 3" />
      {hatch(152, 42, 58, 44, 4)}
      <line x1="146" y1="100" x2="218" y2="103" strokeWidth={1} />
      <line x1="146" y1="110" x2="200" y2="112.5" strokeWidth={1} />
    </svg>
  )
}
```

- [ ] **Step 4: 改两页**

`NotFound.tsx`：import 加 `import { MissingPage } from '@/components/Illustration'`，文件头注释末尾补一句「左边 1px 框里一幅木刻「缺页」（设计说明 2026-10-14 C2）。」，组件换成：

```tsx
export default function NotFound() {
  return (
    <div className="issue-body" style={{ marginTop: 32 }}>
      <Head title="页面不存在" />
      <div className="source-state error-state">
        <div className="error-art"><MissingPage /></div>
        <div className="error-copy">
          <h1 className="state-line">这一页不存在。</h1>
          <Link href={DAILY_LATEST} className="ctrl cjk" style={{ fontSize: 'var(--fs-15)' }}>
            回到首页
          </Link>
        </div>
      </div>
    </div>
  )
}
```

`Forbidden.tsx` 同样改，文字是「你没有权限访问这个页面。」，`Head title="无权访问"`。

- [ ] **Step 5: 样式——`tokens.css` 品质提升段末尾追加**

```css
/* C2 404 / 403：左边 1px 框里一幅「缺页」，右边一句事实加一个动作；手机上下排。与栏级失败态同一装置 */
.error-state { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 32px; align-items: center; }
.error-art { border: 1px solid var(--ink); padding: 16px; }
.error-art svg { display: block; width: 100%; height: auto; }
.error-copy { display: flex; flex-direction: column; align-items: flex-start; gap: 12px; }
@media (max-width: 480px) {
  .error-state { grid-template-columns: minmax(0, 1fr); gap: 20px; }
  .error-art { max-width: 260px; }
}
```

- [ ] **Step 6: 跑，确认通过**

Run: `mise exec -- npx vitest run test/frontend/pages/ErrorPages.test.tsx`
Run: `mise exec -- bin/rails test test/controllers/errors_controller_test.rb`
Expected: 全部 PASS。

- [ ] **Step 7: 目测**

内置浏览器打开 `/no-such-page`（1440 与 390）：框里是对折的报纸、右页被裁掉一块；句子与按钮在右边（手机在下面）。

- [ ] **Step 8: 提交**

```bash
git add app/frontend/components/Illustration.tsx app/frontend/pages/Errors/NotFound.tsx app/frontend/pages/Errors/Forbidden.tsx app/frontend/styles/tokens.css test/frontend/pages/ErrorPages.test.tsx
```

```bash
git -c commit.gpgsign=false commit -m "错误页：404 与 403 加木刻「缺页」，与栏级失败态同一装置" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: 登录页——构图与日出（C1、M6）

**Files:**
- Modify: `app/frontend/components/Illustration.tsx`（`Sunrise` 加 `animated` 与裁切）
- Modify: `app/frontend/pages/Login/Show.tsx`
- Modify: `app/frontend/styles/tokens.css`（品质提升段末尾追加）
- Modify: `app/frontend/styles/motion.css`
- Test: `test/frontend/pages/LoginShow.test.tsx`、`test/system/signing_in_test.rb`

**Interfaces:**
- Consumes: Task 5 的令牌与减少动态效果规则。
- Produces: `Sunrise({ className, animated }: { className?: string; animated?: boolean })`；带动画时 svg 有类 `sunrise--animated`，太阳在 `g.sunrise-sun`（裁在地平线以上），光芒 `line.sunrise-ray`（`--i` 序号、`pathLength=1`），水纹 `path.sunrise-wave`（`pathLength=1`）。

- [ ] **Step 1: 写失败的单测**

加到 `test/frontend/pages/LoginShow.test.tsx` 末尾：

```tsx
it('低通日出带一次性的日出动画；按钮立刻可用，不等动画', () => {
  const { container } = render(<Show providers={['google_oauth2', 'github']} next={null} />)

  const art = container.querySelector('.login-art svg')
  expect(art).toHaveClass('sunrise--animated')
  expect(art?.querySelector('.sunrise-sun')).not.toBeNull()
  expect(art?.querySelectorAll('.sunrise-ray')).toHaveLength(8)
  expect(screen.getByRole('button', { name: '使用 Google 登录' })).toBeEnabled()
})
```

（该文件的 `beforeEach` 已经 `setPageProps({ flash: {} })` 并放好 CSRF meta。）

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/pages/LoginShow.test.tsx`
Expected: 新用例 FAIL。

- [ ] **Step 3: 改 `Sunrise`**

`Illustration.tsx` 顶部 import 改成 `import { useId } from 'react'` 加原有的 `import type * as React from 'react'`；`Sunrise` 换成：

```tsx
// 低通日出：失败态那张小图（画布 130×69，viewBox 260×138）；登录页用 animated 版——太阳从地平线下升起，
// 光芒依次画出，水纹从左向右画出，只播一次（设计 skill「动效」日出，motion.css）。太阳裁在地平线以上，
// 升起前藏在地平线下面，不压到水纹上。
export function Sunrise({ className, animated = false }: { className?: string; animated?: boolean }) {
  const horizon = useId()
  const classes = [className, animated ? 'sunrise--animated' : null].filter(Boolean).join(' ') || undefined

  return (
    <svg viewBox="0 0 260 138" className={classes} fill="none" stroke="var(--ink)" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <defs>
        <clipPath id={horizon}><rect x="0" y="0" width="260" height="84" /></clipPath>
      </defs>
      <g clipPath={`url(#${horizon})`}>
        <g className="sunrise-sun">
          <path d="M96 84 a34 34 0 0 1 68 0 z" fill="var(--green)" />
          <path d="M96 84 a34 34 0 0 1 68 0" />
        </g>
      </g>
      {RAY_ANGLES.map((a, index) => (
        <line
          key={a}
          className="sunrise-ray"
          pathLength={1}
          style={{ '--i': index } as React.CSSProperties}
          x1={round(130 + 44 * Math.cos(a))}
          y1={round(84 - 44 * Math.sin(a))}
          x2={round(130 + 56 * Math.cos(a))}
          y2={round(84 - 56 * Math.sin(a))}
        />
      ))}
      <line x1="14" y1="84" x2="246" y2="84" strokeWidth={2} />
      <path className="sunrise-wave" pathLength={1} d="M14 118 C 50 100 84 104 118 112 S 190 122 246 108" />
      <path className="sunrise-wave" pathLength={1} d="M14 126 C 70 112 120 118 160 124 S 220 130 246 122" strokeWidth={1} />
      <path d="M14 42 l6 -12 l6 16 l6 -20 l6 18 l6 -14 l6 16 l6 -12 l6 10 l6 -14 l6 12 l6 -12 l6 10 l4 -6" strokeWidth={1.4} />
      <rect x="90" y="24" width="30" height="32" fill="var(--paper)" />
      {hatch(92, 26, 26, 28, 4)}
      <path d="M120 40 c 14 -18 28 -18 42 0 s 28 18 42 0 s 28 -18 42 0" strokeWidth={1.6} />
    </svg>
  )
}
```

`Login/Show.tsx`：`<Sunrise />` 改成 `<Sunrise animated />`。

- [ ] **Step 4: 跑单测，确认通过**

Run: `mise exec -- npx vitest run test/frontend/pages/LoginShow.test.tsx test/frontend/pages/DailyShow.test.tsx`
Expected: 全部 PASS（失败态的静态日出不受影响）。

- [ ] **Step 5: 构图与日出样式**

`tokens.css` 品质提升段末尾追加：

```css
/* C1 登录页：整窗纸面上垂直居中，视觉重心略高于几何中心（上下留白 2:3）；内容高过视口时自然滚动 */
.login-ground { min-height: 100dvh; display: grid; grid-template-rows: 2fr auto 3fr; justify-items: center; align-items: start; padding: 24px; box-sizing: border-box; }
.login-card { grid-row: 2; }
```

`motion.css` 在「M7 弹层」之前插入：

```css
/* ─── M6 日出（登录页）────────────────────────────────────────────────── */

/* 太阳从地平线下升起（两个 --dur-3），光芒依次画出（每根错开 --dur-1 的三分之一），水纹从左向右画出；约 1 秒，只播一次 */
.sunrise--animated .sunrise-sun { animation: lp-sun calc(var(--dur-3) * 2) var(--ease-out) both; }
@keyframes lp-sun { from { transform: translateY(34px); } }
.sunrise--animated .sunrise-ray {
  stroke-dasharray: 1; animation: lp-stroke var(--dur-3) var(--ease-out) both;
  animation-delay: calc(var(--dur-3) + var(--i) * var(--dur-1) / 3);
}
.sunrise--animated .sunrise-wave { stroke-dasharray: 1; animation: lp-stroke calc(var(--dur-3) + var(--dur-2)) var(--ease-move) var(--dur-2) both; }
@keyframes lp-stroke { from { stroke-dashoffset: 1; } to { stroke-dashoffset: 0; } }
```

- [ ] **Step 6: 写失败的系统测试**

加到 `test/system/signing_in_test.rb` 的类里（`private` 之前；若没有 `private` 就加在最后一个测试之后）：

```ruby
  # 设计说明 2026-10-14 C1：登录卡在视口里居中，视觉重心略高（上方留白约占 40%）
  test "登录卡在 1440×900 的视口里垂直居中、略偏上" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit login_path

    top, height = evaluate_script("(() => { const r = document.querySelector('.login-card').getBoundingClientRect(); return [r.top, r.height] })()")
    share = top / (900 - height)
    assert_in_delta 0.4, share, 0.06
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
```

- [ ] **Step 7: 构建并跑**

Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/system/signing_in_test.rb`
Expected: 全部 PASS。

- [ ] **Step 8: 目测**

退出登录后的本地登录页（1440×900、390×844）：卡片居中略偏上；太阳从地平线升起、光芒依次出现、水纹画出，约 1 秒停住；按钮一开始就能点。

- [ ] **Step 9: 提交**

```bash
git add app/frontend/components/Illustration.tsx app/frontend/pages/Login/Show.tsx app/frontend/styles/tokens.css app/frontend/styles/motion.css test/frontend/pages/LoginShow.test.tsx test/system/signing_in_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "登录页：卡片在纸面上居中略偏上，低通日出的太阳升起一次" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: 打印（D2）

**Files:**
- Create: `app/frontend/lib/print.ts`
- Create: `app/frontend/styles/print.css`
- Modify: `app/frontend/entrypoints/application.css`（在 motion.css 之后引入 print.css）
- Modify: `app/frontend/pages/Daily/Show.tsx`（打印时渲染全部来源；`SourceBody` 加 `heading` 参数）
- Modify: `app/frontend/components/ItemRow.tsx`（标题链接带 `data-host`）
- Test: `test/frontend/pages/DailyShow.test.tsx`、`test/frontend/components/ItemRow.test.tsx`、`test/system/motion_test.rb`、`test/system/design_rules_test.rb`

**Interfaces:**
- Consumes: Task 6 的 `.source-tabs-frame`（打印时隐藏）；Task 10 的配图叠底。
- Produces: `export function usePrinting(): boolean`；打印 DOM：`.print-sources > section.print-source > h2.print-source-name + .issue-body…`；标题链接 `a.t[data-host]`。

- [ ] **Step 1: 写失败的单测**

加到 `test/frontend/pages/DailyShow.test.tsx` 末尾：

```tsx
describe('打印（D34）', () => {
  it('打印前渲染全部来源、每个来源前印来源名，失败的来源印它的事实句；打印完收回', () => {
    show({
      sources: [
        source(),
        source({ id: 'src-gh', name: 'GitHub Trending', adapter: 'github_trending' }),
        source({ id: 'src-had', name: 'Hackaday', adapter: 'rss', state: 'failed' }),
      ],
      items_by_source: { 'src-hn': [item()], 'src-gh': [item({ id: 'itm-gh-1', url_hash: 'hash-gh', title: 'openclaw/openclaw' })] },
    })
    expect(screen.getAllByRole('tab')).toHaveLength(3)

    act(() => { window.dispatchEvent(new Event('beforeprint')) })
    expect(screen.queryAllByRole('tab')).toHaveLength(0)
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual(['Hacker News', 'GitHub Trending', 'Hackaday'])
    expect(screen.getByText('openclaw/openclaw')).toBeInTheDocument()
    expect(screen.getByText('本期抓取失败，已通知管理员')).toBeInTheDocument()

    act(() => { window.dispatchEvent(new Event('afterprint')) })
    expect(screen.getAllByRole('tab')).toHaveLength(3)
  })

  it('期级事实句（生成中）打印时只印一次', () => {
    show({ issue: dailyIssue({ state: 'generating', status: '生成中，约 1 分钟后刷新' }) })

    act(() => { window.dispatchEvent(new Event('beforeprint')) })
    expect(screen.getAllByText('生成中，约 1 分钟后刷新')).toHaveLength(1)
  })
})
```

加到 `test/frontend/components/ItemRow.test.tsx` 末尾：

```tsx
it('标题链接带域名（打印时印在标题后），去掉 www.', () => {
  render(<ItemRow item={item({ url: 'https://www.example.com/termlog' })} adapter="hacker_news" rank={1} />)

  expect(screen.getByRole('link', { name: 'Show HN: A terminal log viewer written in Rust' })).toHaveAttribute('data-host', 'example.com')
})
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/pages/DailyShow.test.tsx test/frontend/components/ItemRow.test.tsx`
Expected: 新用例 FAIL。

- [ ] **Step 3: 新建 `lib/print.ts`**

```ts
import { useEffect, useState } from 'react'
import { flushSync } from 'react-dom'

// 打印（PRD D34）：日刊页平时只渲染当前来源；打印前把所有来源都渲染出来，打印完收回。
// beforeprint 之后浏览器立刻排打印页，React 的更新得同步落地（flushSync）。打印预览与无头浏览器模拟
// print 媒体时只有 matchMedia('print') 的 change，没有 beforeprint，两路都听。
export function usePrinting(): boolean {
  const [printing, setPrinting] = useState(false)

  useEffect(() => {
    const start = () => flushSync(() => setPrinting(true))
    const end = () => setPrinting(false)
    const media = window.matchMedia?.('print')
    const change = (event: MediaQueryListEvent) => (event.matches ? start() : end())
    window.addEventListener('beforeprint', start)
    window.addEventListener('afterprint', end)
    media?.addEventListener?.('change', change)
    return () => {
      window.removeEventListener('beforeprint', start)
      window.removeEventListener('afterprint', end)
      media?.removeEventListener?.('change', change)
    }
  }, [])

  return printing
}
```

- [ ] **Step 4: 日刊页打印时渲染全部来源**

`pages/Daily/Show.tsx`：import 加 `import { usePrinting } from '@/lib/print'` 与（若未导入）`import { latinLang } from '@/lib/typeset'`。

`SourceBody` 改签名并把 `heading` 传给条目：

```tsx
function SourceBody({ source, items, heading = 'h2' }: { source: SourceSummary; items: Item[]; heading?: 'h2' | 'h3' }) {
```

里面 `<ItemRow … />` 加 `heading={heading}`。

`Sources` 里 `const [activeId, setActiveId] = useState(activeSourceId)` 之后加 `const printing = usePrinting()`；在 `if (!active) return …` 之后、`return (<SourceTabs …>)` 之前加：

```tsx
  // 打印时印出全部来源，每个来源前印来源名（PRD D34）；期级事实句只印一次。平时一次只显示一个来源（PRD 6.2）
  if (printing) {
    if (notice) return <IssueNotice text={notice} />
    return (
      <div className="print-sources">
        {sources.map((source) => (
          <section key={source.id} className="print-source">
            <h2 className="print-source-name" lang={latinLang(source.name)}>{source.name}</h2>
            <SourceBody source={source} items={itemsBySource[source.id] ?? []} heading="h3" />
          </section>
        ))}
      </div>
    )
  }
```

- [ ] **Step 5: 标题链接带域名**

`ItemRow.tsx` 在 `Translation` 之前加：

```tsx
// 打印时标题后印链接的域名（print.css 读 data-host）；地址解析不了就不印
function hostOf(url: string): string | undefined {
  try {
    return new URL(url).host.replace(/^www\./, '')
  } catch {
    return undefined
  }
}
```

标题 `<a className="t" …>` 加属性 `data-host={hostOf(item.url)}`。

- [ ] **Step 6: 跑单测，确认通过**

Run: `mise exec -- npx vitest run test/frontend/pages/DailyShow.test.tsx test/frontend/components/ItemRow.test.tsx`
Expected: 全部 PASS。

- [ ] **Step 7: 新建 `styles/print.css` 并引入**

```css
/* 打印（PRD D34，设计说明 2026-10-14 D2）：一份日刊打出来是一张排好的报纸——白底墨字，交互件不印，条目不跨页。
   打印页宽在 700px 上下，手机断点的规则也会生效；这里写在 tokens.css 与 motion.css 之后，同权重以这里为准。 */
@media print {
  @page { margin: 16mm 14mm; }
  html, body, .paper { background: none !important; }
  .sheet { min-height: 0; }
  .sheet-body { max-width: none; padding: 0; }

  /* 报头：墨带改成白底墨字加一条 2px 线；导航、搜索、头像不印 */
  .masthead { height: auto; min-height: 0; padding: 0 0 8pt 0; background: none; border-bottom: 2px solid var(--ink); }
  .masthead-brand { color: var(--ink); }
  .masthead-nav, .masthead-actions, .skip-link, .toasts, #nprogress { display: none !important; }

  /* 交互件不印：期导航、书签、索引条、目录、返回链接、栏尾外链、页脚的按钮与链接、搜索框与筛选 */
  .issue-nav, .issue-nav-mobile, .page-nav, .favorite-button, .source-tabs-frame, .weekly-directory, .directory-return,
  .source-foot, footer a, footer .ctrl, .search-head, .filters-shell, .search-pager { display: none !important; }

  .print-source-name { margin: 18pt 0 6pt; font-family: var(--font-latin); font-weight: 600; font-size: var(--fs-20); break-after: avoid; }
  .item-row { break-inside: avoid; grid-template-columns: 28px minmax(0, 1fr); grid-template-areas: "rank body"; }
  .item-title a.t { text-decoration: none; }
  .item-title a.t[data-host]::after { content: "  " attr(data-host); font-family: var(--font-data); font-size: var(--fs-12); font-weight: 400; color: var(--ink2); }
  .item-reason { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .item-media-image { mix-blend-mode: normal; }

  /* 周刊横带：白底墨字，上 2px、下 1px 两条线 */
  .source-band { background: none; color: var(--ink); border-top: 2px solid var(--ink); border-bottom: 1px solid var(--ink); }
  .source-band span { color: var(--ink) !important; }
  footer { break-inside: avoid; }
}
```

`application.css`：`@import "../styles/motion.css";` 之后加 `@import "../styles/print.css";`。

- [ ] **Step 8: 写失败的系统测试**

加到 `test/system/motion_test.rb` 的 `private` 之前：

```ruby
  test "D2 打印媒体下三个来源都印出来，书签与索引条不印" do
    visit daily_issue_path("2026-09-08")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")

    assert_selector ".print-source-name", count: 3
    assert_equal "none", evaluate_script("getComputedStyle(document.querySelector('.favorite-button')).display")
    assert_no_selector ".source-tabs-frame"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end
```

加到 `test/system/design_rules_test.rb` 的 `private` 之前：

```ruby
  test "D2 打印时配图不叠底，报头是白底墨字" do
    render_fragment(%(<header class="masthead"><a class="masthead-brand">lowpass</a></header><img class="item-media-image" alt="">), media: "print")

    assert_equal "normal", style(".item-media-image", "mix-blend-mode")
    assert_equal "rgba(0, 0, 0, 0)", style(".masthead", "background-color")
    assert_equal INK, style(".masthead-brand", "color")
  end
```

- [ ] **Step 9: 构建并跑**

Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/system/motion_test.rb test/system/design_rules_test.rb`
Expected: 全部 PASS。

- [ ] **Step 10: 打印预览目测**

本地开发库的最新日刊，Chrome 打印预览（或内置浏览器 CDP 模拟 print 后截图）：三个来源依次排开、每个来源前有来源名；没有书签与按钮；标题后有灰色域名；推荐理由的绿线在。周刊页打印：横带是白底墨字。

- [ ] **Step 11: 提交**

```bash
git add app/frontend/lib/print.ts app/frontend/styles/print.css app/frontend/entrypoints/application.css app/frontend/pages/Daily/Show.tsx app/frontend/components/ItemRow.tsx test/frontend/pages/DailyShow.test.tsx test/frontend/components/ItemRow.test.tsx test/system/motion_test.rb test/system/design_rules_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "打印：日刊印出全部来源，白底墨字，交互件不印，标题后印域名" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: `<head>` 元信息、manifest、分享卡片（D1）

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `public/manifest.webmanifest`
- Create: `docs/design/notes/2026-10-14-og-card.html`（分享图的源稿）
- Create: `public/og.png`（由源稿渲染）
- Create: `test/integration/head_meta_test.rb`

**Interfaces:**
- Consumes: 无。
- Produces: 每页 `<head>` 的 theme-color、description、manifest、og:* 与 twitter:card；`HeadMetaTest`（Task 15 往里加用例）。

- [ ] **Step 1: 写失败的集成测试**

新建 `test/integration/head_meta_test.rb`：

```ruby
require "test_helper"

# 设计说明 2026-10-14 D1：每一页的 <head> 都带主题色、简介、manifest 与分享卡片。
# 登录页是唯一对外可见的页面，分享出去的链接都会落到它上面。
class HeadMetaTest < ActionDispatch::IntegrationTest
  TAGLINE = "每天一期技术日刊，登录后阅读".freeze

  test "登录页的 head 带主题色、简介、manifest 与分享卡片" do
    get login_path

    assert_response :success
    assert_select "meta[name=theme-color][content='#1D1D1B']"
    assert_select "meta[name=description][content=?]", TAGLINE
    assert_select "link[rel=manifest][href='/manifest.webmanifest']"
    assert_select "meta[property='og:site_name'][content=Lowpass]"
    assert_select "meta[property='og:description'][content=?]", TAGLINE
    assert_select "meta[property='og:image'][content$='/og.png']"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
  end

  test "manifest 用纸色与墨色，分享图 1200×630 且不超过 150 KB" do
    manifest = JSON.parse(Rails.root.join("public/manifest.webmanifest").read)
    assert_equal "#1D1D1B", manifest["theme_color"]
    assert_equal "#E8E3DA", manifest["background_color"]
    assert_equal "standalone", manifest["display"]
    assert_equal "/", manifest["start_url"]

    png = Rails.root.join("public/og.png")
    assert png.exist?
    assert_operator png.size, :<=, 150.kilobytes
    assert_equal [ 1200, 630 ], png.binread[16, 8].unpack("NN")
  end
end
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- bin/rails test test/integration/head_meta_test.rb`
Expected: FAIL（没有这些标签与文件）。

- [ ] **Step 3: 改布局**

`application.html.erb` 在 `<meta name="mobile-web-app-capable" content="yes">` 之后加：

```erb
    <%# 设计说明 2026-10-14 D1：简介用附录 B 的登录页一句话；手机浏览器顶栏跟报头墨带同色；分享卡片落在登录页上也成立 %>
    <meta name="description" content="每天一期技术日刊，登录后阅读">
    <meta name="theme-color" content="#1D1D1B">
    <link rel="manifest" href="/manifest.webmanifest">
    <meta property="og:site_name" content="Lowpass">
    <meta property="og:type" content="website">
    <meta property="og:title" content="Lowpass">
    <meta property="og:description" content="每天一期技术日刊，登录后阅读">
    <meta property="og:image" content="<%= request.base_url %>/og.png">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta name="twitter:card" content="summary_large_image">
```

并删掉布局里那两行已注释掉的 PWA manifest 提示（`<%# Enable PWA manifest … %>` 与 `<%#= tag.link rel: "manifest" … %>`），它们被上面的 manifest 取代。

- [ ] **Step 4: 新建 `public/manifest.webmanifest`**

```json
{
  "name": "Lowpass",
  "short_name": "Lowpass",
  "description": "每天一期技术日刊，登录后阅读",
  "lang": "zh-CN",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#E8E3DA",
  "theme_color": "#1D1D1B",
  "icons": [
    { "src": "/icon.png?v=3", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "/icon.svg?v=3", "sizes": "any", "type": "image/svg+xml", "purpose": "any" }
  ]
}
```

- [ ] **Step 5: 分享图源稿**

新建 `docs/design/notes/2026-10-14-og-card.html`。版面按 600×315 的 CSS 像素排、以 2 倍渲染成 1200×630，字号全部取令牌里的值（品牌 40、简介 20），不放大：

```html
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>Lowpass 分享卡片（源稿）</title>
<!-- 设计说明 2026-10-14 D1：分享卡片。按 600×315 排、用 2 倍像素渲染成 public/og.png（1200×630）：
     "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=2 --window-size=600,315 --screenshot=public/og.png "file://$PWD/docs/design/notes/2026-10-14-og-card.html"
     字体直接引仓库里的子集：Bodoni 子集只含 LOWPASS 几个字母，文楷界面子集含登录页那句话。 -->
<style>
  @font-face { font-family: "Bodoni Brand"; src: url("../../../app/frontend/fonts/bodoni-moda-brand.woff2") format("woff2"); font-weight: 900; }
  @font-face { font-family: "WenKai UI"; src: url("../../../app/frontend/fonts/lxgw-wenkai-screen-ui.woff2") format("woff2"); }
  html, body { margin: 0; width: 600px; height: 315px; overflow: hidden; background: #E8E3DA; color: #1D1D1B; }
  .band { height: 80px; background: #1D1D1B; display: flex; align-items: center; justify-content: center; }
  .brand { font-family: "Bodoni Brand", serif; font-weight: 900; font-size: 40px; letter-spacing: 0.02em; color: #E8E3DA; line-height: 1; }
  .body { display: flex; align-items: center; justify-content: center; gap: 32px; height: 235px; }
  .art { border: 1px solid #1D1D1B; padding: 12px; width: 236px; }
  .art svg { display: block; width: 100%; height: auto; }
  .tagline { font-family: "WenKai UI", serif; font-size: 20px; line-height: 1.6; width: 200px; }
</style>
</head>
<body>
  <div class="band"><span class="brand">LOWPASS</span></div>
  <div class="body">
    <div class="art">
      <!-- 与 app/frontend/components/Illustration.tsx 的 Sunrise 同一幅（终态） -->
      <svg viewBox="0 0 260 138" fill="none" stroke="#1D1D1B" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
        <path d="M96 84 a34 34 0 0 1 68 0 z" fill="#96B59F"/>
        <path d="M96 84 a34 34 0 0 1 68 0"/>
        <line x1="171.3" y1="68.9" x2="182.6" y2="64.8"/><line x1="163.7" y1="55.7" x2="172.8" y2="47.9"/><line x1="151.9" y1="45.8" x2="157.9" y2="35.4"/><line x1="137.5" y1="40.6" x2="139.5" y2="28.8"/><line x1="122.2" y1="40.7" x2="120" y2="28.9"/><line x1="107.8" y1="46" x2="101.7" y2="35.7"/><line x1="96.1" y1="55.9" x2="86.9" y2="48.3"/><line x1="88.5" y1="69.3" x2="77.2" y2="65.2"/>
        <line x1="14" y1="84" x2="246" y2="84" stroke-width="2"/>
        <path d="M14 118 C 50 100 84 104 118 112 S 190 122 246 108"/>
        <path d="M14 126 C 70 112 120 118 160 124 S 220 130 246 122" stroke-width="1"/>
        <path d="M14 42 l6 -12 l6 16 l6 -20 l6 18 l6 -14 l6 16 l6 -12 l6 10 l6 -14 l6 12 l6 -12 l6 10 l4 -6" stroke-width="1.4"/>
        <rect x="90" y="24" width="30" height="32" fill="#E8E3DA"/>
        <path d="M92 50 L96 54 M92 46 L100 54 M92 42 L104 54 M92 38 L108 54 M92 34 L112 54 M92 30 L116 54 M92 26 L118 52 M96 26 L118 48 M100 26 L118 44 M104 26 L118 40 M108 26 L118 36 M112 26 L118 32 M116 26 L118 28" stroke-width="0.9"/>
        <path d="M120 40 c 14 -18 28 -18 42 0 s 28 18 42 0 s 28 -18 42 0" stroke-width="1.6"/>
      </svg>
    </div>
    <p class="tagline">每天一期技术日刊，登录后阅读</p>
  </div>
</body>
</html>
```

（光芒端点与排线是按 `Illustration.tsx` 里 `RAY_ANGLES`、`hatch(92, 26, 26, 28, 4)` 的公式算出的值，四舍五入到 0.1。）

- [ ] **Step 6: 渲染分享图**

Run: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=2 --window-size=600,315 --screenshot=public/og.png "file://$PWD/docs/design/notes/2026-10-14-og-card.html"`
Run: `sips -g pixelWidth -g pixelHeight public/og.png`
Expected: 1200 × 630；用 Read 打开 `public/og.png` 目测：字体是 Bodoni 与文楷（没有掉进系统字体）。若超过 150 KB，删掉源稿里任何纹理或把截图改成 `--screenshot` 后用 `sips -s format png` 重存，不降低尺寸。

- [ ] **Step 7: 跑，确认通过**

Run: `mise exec -- bin/rails test test/integration/head_meta_test.rb test/controllers/sessions_controller_test.rb`
Expected: 全部 PASS。

- [ ] **Step 8: 提交**

```bash
git add app/views/layouts/application.html.erb public/manifest.webmanifest public/og.png docs/design/notes/2026-10-14-og-card.html test/integration/head_meta_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "元信息：主题色、简介、manifest 与分享卡片（纸面报头图）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: 首屏——正文字体声明移出阻塞渲染（D3、D4）

**Files:**
- Create: `app/frontend/entrypoints/fonts-content.css`
- Create: `app/frontend/lib/contentFonts.ts`
- Modify: `app/frontend/styles/fonts.css`（去掉文楷包的 import）
- Modify: `app/frontend/entrypoints/application.tsx`
- Modify: `app/views/layouts/application.html.erb`（preload）
- Modify: `script/first_screen_size`（注释写明口径）
- Modify: `docs/engineering-conventions.md`（首屏预算一段）
- Test: `test/frontend/lib/contentFonts.test.ts`、`test/integration/head_meta_test.rb`

**Interfaces:**
- Consumes: Task 14 的 `HeadMetaTest`。
- Produces: `export function loadContentFonts(doc?: Document): void`；布局里 `link[rel=preload][as=style][data-content-fonts]`。

- [ ] **Step 1: 写失败的单测与集成测试**

新建 `test/frontend/lib/contentFonts.test.ts`：

```ts
import { afterEach, describe, expect, it } from 'vitest'

import { loadContentFonts } from '@/lib/contentFonts'

// 正文字体声明（设计说明 2026-10-14 D3）：布局里 preload 的那张表，应用启动时挂成样式表，只挂一次

afterEach(() => {
  document.head.innerHTML = ''
})

describe('loadContentFonts', () => {
  it('把 preload 的那张表挂成样式表', () => {
    document.head.innerHTML = '<link rel="preload" as="style" href="/vite/assets/fonts-content-abc.css" data-content-fonts>'

    loadContentFonts()

    const sheet = document.head.querySelector<HTMLLinkElement>('link[rel="stylesheet"][data-content-fonts-applied]')
    expect(sheet?.getAttribute('href')).toBe('/vite/assets/fonts-content-abc.css')
  })

  it('只挂一次', () => {
    document.head.innerHTML = '<link rel="preload" as="style" href="/a.css" data-content-fonts>'

    loadContentFonts()
    loadContentFonts()

    expect(document.head.querySelectorAll('link[rel="stylesheet"]')).toHaveLength(1)
  })

  it('页面没有 preload（登录页以外的静态页、单测）时什么都不做', () => {
    loadContentFonts()

    expect(document.head.querySelectorAll('link')).toHaveLength(0)
  })
})
```

加到 `test/integration/head_meta_test.rb` 的类里：

```ruby
  test "正文字体声明 preload 成样式表，不在阻塞渲染的 CSS 里" do
    get login_path

    assert_select "link[rel=preload][as=style][data-content-fonts][href$='.css']"
  end
```

- [ ] **Step 2: 跑，确认失败**

Run: `mise exec -- npx vitest run test/frontend/lib/contentFonts.test.ts`
Run: `mise exec -- bin/rails test test/integration/head_meta_test.rb`
Expected: 都 FAIL。

- [ ] **Step 3: 实现**

新建 `app/frontend/entrypoints/fonts-content.css`：

```css
/* 正文字体声明（设计说明 2026-10-14 D3）：霞鹜文楷 97 个分片的 @font-face 有 32 KB（gzip），不该挡着首屏渲染。
   布局里 preload 这张表，lib/contentFonts.ts 在应用启动时把它挂成样式表。界面子集在包的分片之后再声明一遍：
   unicode-range 重叠时后声明的先用，界面字仍从子集取（与 styles/fonts.css 同一条规则）。 */
@import "lxgw-wenkai-screen-webfont/lxgwwenkaiscreen.css";
@import "../styles/fonts-subset.css";
```

`app/frontend/styles/fonts.css`：删掉 `@import "lxgw-wenkai-screen-webfont/lxgwwenkaiscreen.css";` 这一行；把文件头注释里「霞鹜文楷 Screen：只引 lxgwwenkaiscreen.css 这一个家族（97 片，…）」一段改成：

```css
   霞鹜文楷 Screen：包的 97 个分片声明不在这里——它们在 entrypoints/fonts-content.css，布局 preload、启动时挂上，
   不挡首屏（设计说明 2026-10-14 D3）。这里只留界面子集：每页都有的界面字在首屏就有字形。
```

新建 `app/frontend/lib/contentFonts.ts`：

```ts
// 正文字体声明（设计说明 2026-10-14 D3）：布局里 preload 的那张表（文楷 97 个分片的 @font-face），
// 应用启动时挂成样式表——不挡首屏渲染，正文里的汉字照旧按 unicode-range 按需下载分片。只挂一次。
export function loadContentFonts(doc: Document = document): void {
  const preload = doc.querySelector<HTMLLinkElement>('link[data-content-fonts]')
  if (!preload || doc.querySelector('link[data-content-fonts-applied]')) return

  const link = doc.createElement('link')
  link.rel = 'stylesheet'
  // 照抄属性原文（不读解析成绝对地址的 .href）：与 preload 是同一个 URL，浏览器直接用 preload 下好的那份
  link.setAttribute('href', preload.getAttribute('href') ?? preload.href)
  link.setAttribute('data-content-fonts-applied', '')
  doc.head.appendChild(link)
}
```

`application.tsx`：import 加 `import { loadContentFonts } from '@/lib/contentFonts'`，`focusMainOnNavigate()` 之前加一行 `loadContentFonts()`。

`application.html.erb`：文楷界面子集那行 preload 之后加：

```erb
    <%# 正文字体声明不挡首屏：先 preload，lib/contentFonts.ts 启动时挂成样式表（设计说明 2026-10-14 D3） %>
    <link rel="preload" as="style" href="<%= vite_asset_path "fonts-content.css" %>" data-content-fonts>
```

`script/first_screen_size` 文件头注释的「首屏 = …」那段末尾加一条：

```ruby
#   - 不计：entrypoints/fonts-content.css（文楷 97 个分片的 @font-face 声明）。它由布局 preload、启动时挂上，
#     不阻塞渲染；跟按需下载的正文字体分片一样属于内容，不是界面（设计说明 2026-10-14 D3）
```

`docs/engineering-conventions.md` 第 140 行那段末尾加一句：

```markdown
文楷包 97 个分片的 `@font-face` 声明（gzip 后 32 KB）不放进阻塞渲染的 `application.css`：它们在 `entrypoints/fonts-content.css`，布局里 preload、`lib/contentFonts.ts` 启动时挂上，首屏预算不计（它和按需下载的分片一样是内容）。界面子集在两处都声明，保证界面字始终从子集取。
```

- [ ] **Step 4: 跑，确认通过**

Run: `mise exec -- npx vitest run test/frontend/lib/contentFonts.test.ts`
Run: `env RAILS_ENV=test mise exec -- bin/vite build --mode test`
Run: `mise exec -- bin/rails test test/integration/head_meta_test.rb`
Expected: 全部 PASS。

- [ ] **Step 5: 量预算（D3、D4）**

Run: `mise exec -- npm run build`
Run: `mise exec -- ruby script/first_screen_size`
Expected: 合计 ≤ 300 KB，`CSS assets/application-*.css` 一行约 13–17 KB（改动前 44.48 KB）。把改动前后的 JS、CSS 合计与差值记进 Task 16 的轮次笔记：本次新增 JS ≤ 3 KB、CSS ≤ 4 KB（不含挪走的 32 KB）。

- [ ] **Step 6: 冷缓存下的换字与 CLS**

内置浏览器打开最新日刊，DevTools 协议 `Network.setCacheDisabled` 或强制刷新后：界面字一开始就是文楷；推荐理由里的汉字短暂回退后换成文楷；用 `PerformanceObserver` 量 `layout-shift` 合计仍为 0。若 CLS 不为 0，先查是哪一行在换字时改了行数，记进轮次笔记再决定是否给回退字体加 `size-adjust`。

- [ ] **Step 7: 提交**

```bash
git add app/frontend/entrypoints/fonts-content.css app/frontend/lib/contentFonts.ts app/frontend/styles/fonts.css app/frontend/entrypoints/application.tsx app/views/layouts/application.html.erb script/first_screen_size docs/engineering-conventions.md test/frontend/lib/contentFonts.test.ts test/integration/head_meta_test.rb
```

```bash
git -c commit.gpgsign=false commit -m "首屏：文楷分片的字体声明移出阻塞渲染的 CSS，启动时挂上" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: 自查轮次与收尾

**Files:**
- Create: `tmp/quality_matrix.rb`（`tmp/` 不入库）
- Create: `tmp/seed_states.rb`（`tmp/` 不入库）
- Create: `docs/design/notes/2026-10-14-quality-rounds.md`
- Modify: 每一轮发现的问题所在的文件（按问题定）

**Interfaces:**
- Consumes: Task 1–15 的全部产出；设计说明第 7 节的清单与评分锚点。
- Produces: 轮次笔记（每轮的评分表、证据、修复清单）；达标后的分支。

- [ ] **Step 1: 造各种状态的开发数据**

新建 `tmp/seed_states.rb`（只给本地开发库，`bin/rails runner tmp/seed_states.rb`）：

```ruby
# 品质自查要看到空刊与抓取失败两种状态：在开发库里造两期。只在 development 下跑，可反复跑。
abort "只在 development 下跑" unless Rails.env.development?

Issue.daily.where(period_key: %w[ 2026-10-09 2026-10-10 ]).find_each do |issue|
  FetchRun.where(issue: issue).delete_all
  issue.destroy!
end

Issue.create!(kind: "daily", period_key: "2026-10-10", state: "empty", generation_started_at: Time.utc(2026, 10, 9, 22), published_at: Time.utc(2026, 10, 9, 22, 5), source_states: {})

source = Source.enabled.daily.ordered.first
failed = Issue.daily.find_by!(period_key: "2026-10-11")
copy = Issue.create!(kind: "daily", period_key: "2026-10-09", state: "published", generation_started_at: failed.generation_started_at - 2.days, published_at: failed.published_at - 2.days,
                     source_states: failed.source_states.merge(source.id => "failed"))
failed.items.where.not(source: source).find_each { |item| copy.items.create!(item.attributes.except("id", "issue_id", "created_at", "updated_at")) }
puts "ok"
```

（`Issue` 只校验 kind、period_key、state，其余列有默认值；条目的 `url_hash` 只在同一期里唯一，复制到新的一期不冲突。）

Run: `mise exec -- bin/rails runner tmp/seed_states.rb`

- [ ] **Step 2: 写截图矩阵脚本**

新建 `tmp/quality_matrix.rb`：

```ruby
# 品质自查的截图矩阵（设计说明 2026-10-14 第 7 节）。只给本地开发库用：先起
#   ADMIN_EMAILS=reader@lowpass.test mise exec -- bin/rails server -p 3000   与   mise exec -- bin/vite dev
# 再  mise exec -- ruby tmp/quality_matrix.rb r1
# 输出 tmp/quality/<轮次>/<页面>-<宽度>.png 与 report.json（每张图的横向溢出量与浏览器报错）。
require "selenium-webdriver"
require "fileutils"
require "json"
require "base64"

ROUND = ARGV.fetch(0, "r1")
BASE = "http://localhost:3000"
OUT = File.expand_path("quality/#{ROUND}", __dir__)
WIDTHS = [ 320, 375, 390, 481, 600, 768, 1024, 1440, 1920, 2560 ].freeze
PAGES = {
  "daily" => "/daily/2026-10-13",
  "daily-empty" => "/daily/2026-10-10",
  "daily-failed" => "/daily/2026-10-09",
  "weekly" => "/weekly/2026-W42",
  "daily-archive" => "/daily",
  "weekly-archive" => "/weekly",
  "search" => "/search",
  "search-results" => "/search?q=agent",
  "search-empty" => "/search?q=zzqqxx",
  "favorites" => "/favorites",
  "settings" => "/settings",
  "not-found" => "/no-such-page",
  "admin-sources" => "/admin/sources",
  "admin-settings" => "/admin/settings",
}.freeze

def driver
  options = Selenium::WebDriver::Chrome::Options.new(args: %w[ --headless=new --hide-scrollbars --window-size=1400,1000 ])
  options.add_option("goog:loggingPrefs", { browser: "SEVERE" })
  Selenium::WebDriver.for(:chrome, options: options)
end

def sign_in(browser, email)
  browser.navigate.to "#{BASE}/login"
  browser.find_element(css: "input[name=name]").send_keys("Reader")
  browser.find_element(css: "input[name=email]").send_keys(email)
  browser.find_element(css: "button[type=submit]").click
  sleep 1
end

def shoot(browser, name, width)
  browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
  sleep 0.6
  metrics = browser.execute_cdp("Page.getLayoutMetrics")
  height = [ metrics["cssContentSize"]["height"].ceil, 7000 ].min
  data = browser.execute_cdp("Page.captureScreenshot", format: "png", captureBeyondViewport: true, clip: { x: 0, y: 0, width: width, height: height, scale: 1 })["data"]
  File.binwrite(File.join(OUT, "#{name}-#{width}.png"), Base64.decode64(data))
  overflow = browser.execute_script("return document.documentElement.scrollWidth - document.documentElement.clientWidth")
  { page: name, width: width, overflow: overflow, errors: browser.logs.get(:browser).map(&:message) }
end

FileUtils.mkdir_p(OUT)
report = []

reader = driver
sign_in(reader, "reader@lowpass.test")
PAGES.each do |name, path|
  reader.navigate.to "#{BASE}#{path}"
  sleep 1
  WIDTHS.each { |width| report << shoot(reader, name, width) }
end
# 日刊的另外两个来源
%w[ 1 2 ].each do |index|
  reader.navigate.to "#{BASE}#{PAGES["daily"]}"
  sleep 1
  reader.find_elements(css: ".source-tabs:not(.source-tabs-ink) [role=tab]")[index.to_i].click
  sleep 0.5
  WIDTHS.each { |width| report << shoot(reader, "daily-tab#{index}", width) }
end
reader.quit

# 登录页（未登录）与 403（非管理员）
guest = driver
guest.navigate.to "#{BASE}/login"
sleep 1.5
WIDTHS.each { |width| report << shoot(guest, "login", width) }
sign_in(guest, "member@lowpass.test")
guest.navigate.to "#{BASE}/admin/sources"
sleep 1
WIDTHS.each { |width| report << shoot(guest, "forbidden", width) }
guest.quit

File.write(File.join(OUT, "report.json"), JSON.pretty_generate(report))
bad = report.select { |row| row[:overflow].to_i > 0 || row[:errors].any? }
puts "#{report.size} 张，问题 #{bad.size} 张"
bad.each { |row| puts "  #{row[:page]} #{row[:width]}px 溢出 #{row[:overflow]} 报错 #{row[:errors].size}" }
```

- [ ] **Step 3: 跑第一轮**

Run: `mise exec -- ruby tmp/quality_matrix.rb r1`
Expected: 输出张数与问题清单；`report.json` 里溢出与报错都应为 0。

- [ ] **Step 4: 逐张看图、填第一轮评分表**

用 Read 打开 `tmp/quality/r1/` 下的截图（每个页面至少看 320、390、768、1440、2560 五张），对照设计说明第 7 节的清单 1–8 逐条打勾；动效（M1–M8）用内置浏览器逐帧检查（`document.getAnimations().forEach((a) => a.playbackRate = 0.1)` 后截中间帧）；减少动态效果用 CDP `Emulation.setEmulatedMedia` 的 `prefers-reduced-motion: reduce` 复查；键盘路径手走一遍。

新建 `docs/design/notes/2026-10-14-quality-rounds.md`，第一轮写成：

```markdown
# 品质自查轮次（设计说明 2026-10-14 第 7 节）

## 第 1 轮（日期、提交）

| 清单 | 结果 | 证据 |
|---|---|---|
| 1 设计 skill 原有 7 条 | 过 / 不过 | 截图文件名与说明 |
| 2 无溢出、重叠、孤悬；线宽只有 1px / 2px | | report.json 的统计、截图 |
| 3 Q1–Q5、T1–T6、C1–C4、E1–E2、D1–D3 | | 逐条 |
| 4 M1–M8 逐帧；动效中可点可滚；减少动态时关闭 | | 帧截图 |
| 5 键盘路径 | | 手走记录 |
| 6 CLS、LCP 增量、长任务、首屏 | | 测量值 |
| 7 打印预览、手机顶栏、分享卡片 | | 截图 |
| 8 bin/ci | | 输出摘要 |

| 维度 | 自评 | 理由（逐条对应上面的证据） |
|---|---|---|
| 设计 | | |
| 可用性 | | |
| 创意 | | |
| 内容 | | |
| 开发者：语义 / 动效 / 无障碍 / 性能 / 响应式 / 元信息 | | |

没过的项与修法：

1. …
```

T7（Newsreader 光学尺寸）在这一轮记为「不上」：fontsource 的拉丁 opsz 文件 132 KB，比现在用的 wght 文件（56.7 KB）多出 75 KB，即使挪走文楷声明腾出的 32 KB 也装不进 300 KB 预算。

- [ ] **Step 5: 修第一轮没过的项**

每一项按 TDD：能量化的先在 `design_rules_test.rb` 或对应单测里加失败的用例，再改，再跑；每个独立的问题一个提交，提交信息写「自查第 1 轮：…」。

- [ ] **Step 6: 跑下一轮，直到达标**

重复 Step 3–5（`r2`、`r3`…），每轮在轮次笔记里追加同样的两张表。达标判定按设计说明第 1 节：清单全过、每个维度自评达到目标分（设计 ≥ 7.5、可用性 ≥ 8、创意 ≥ 7.5、内容 ≥ 7.5、开发者各项 ≥ 7.5），且评分理由逐条有证据；8.5 以上不自封。

- [ ] **Step 7: 全量门禁**

Run: `VITE_RUBY_AUTO_BUILD=false mise exec -- bin/ci`
Expected: 全部步骤绿；首屏 ≤ 300 KB。把输出摘要记进轮次笔记的最后一轮。

- [ ] **Step 8: 提交轮次笔记**

```bash
git add docs/design/notes/2026-10-14-quality-rounds.md
```

```bash
git -c commit.gpgsign=false commit -m "文档：品质自查轮次记录（评分表与证据）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: 整支分支评审、推送、开 PR**

按选定的执行方式做整支分支评审，修完复审干净后推送分支，开 PR（base `main`），描述里列出设计说明、计划、轮次笔记三个文件与每轮的评分。合并由产品负责人执行（本机的命令分类器会拒绝 `gh pr merge`）；合并后 CI 通过会自动部署。

- [ ] **Step 10: 生产复核（合并部署之后）**

用产品负责人的 Chrome（Claude in Chrome，新开标签页），按 2026-10-14 评估同样的页面与宽度（1440、600、390 的同源 iframe 并排）再走一遍：横带图标、索引条线宽、标签位置、「read more」、翻页、墨块、盖章、开场、打印预览、`<head>` 标签。结果追加到轮次笔记的「生产复核」一节并提交（另开一个小 PR 或随下一次改动带上）。
