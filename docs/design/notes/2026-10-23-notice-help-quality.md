# 期级事实句与部署帮助的实际可读性

本轮从 main `c1f47954b56f4d8c08d58f02a9beab0ee61b8081` 独立修复，不包含尚未合并的PR69–78，不涉及业务数据、模型、OAuth或生产发布。奖项品质目标仍未完成，本轮不赋予新的整站评分。

## 两个根因

320px 的日刊空刊提示末行为“知”，同一组件的周刊降级提示末行为“接”。现有 `.state-line` 虽声明 `text-wrap:balance`，IssueNotice 使用 inline span，没有独立的段落行框。只把这个事实句改为 p，复用已有 margin:0、20px文楷和balance，不改原文或SourceState布局。段落形成真实行框后，原匿名行盒带来的0.5–1px高度差会消失，不能称像素完全相同。

未配置告警或备份时的两个帮助入口没有命中既有目标规则。375px以上实际只有104×15px；320px又拆成65×15与39×15两段，union中心为空。最终将说明span和帮助a拆为既有 `.admin-actions` 的相邻flex项，沿用gap12和换行；既有 `.search-links > a` 选择器扩到 `a.field-note`，复用流内44px高度、宽度约束与断行规则。帮助使用现有 `.t` 下划线，保持13px字体、原文、href和既有键盘路径，不用会覆盖备注/禁用按钮的扩散层。

## 可复核证据

证据根目录：`/Users/drewlee/.codex/visualizations/2026/10/22/01a162a8-dbb7-7583-bab0-a4e6384d008a/notice-help-quality/`。

- `notice-diagnosis/`：100个基线页面、140组原样Range与50组单变量display:block诊断。注入只是确认根因，不能当正式候选通过。
- `help-diagnosis/`：16组原样页面、6次自然键盘路径及320px真实碎片。全仓同类备注内链接只有这两处。原生Tab/Enter本来正常，不把它误报为键盘不可达。
- `additional-inputs/`：8份真实控制器GET HTML/props，235条断言通过，独立临时PostgreSQL18库事务回滚并DROP。补齐仅告警、仅备份、合法部分配置、Sources空/停用、收藏无摘要/译文和普通成员缺期；无手造props或真实任务执行。
- `system-red-confirmed.log`：3项测试、15条断言、3个预期失败；`prefix-boundary-red.log`另证明旧嵌套结构在375px有15个备注字框点命中链接。最终 `system-v2-green.log` 为3项测试、204条断言通过，包含72次可信原生点击、严格备注保护与两条实际字形行盒回归。
- `independent-review/v2-review.md`：三个产品文件与系统回归 bounded no findings；4个相关前端文件91项测试通过，实际源码与冻结包一致。原V1评审保留，不冒充最终评审。
- `full-ci-v2.log`：最终前端454、Rails856/3763 assertions、系统80/8248 assertions全绿，首屏264.58KB，预算300KB，总59.67秒。先前 `full-ci.log` 只代表V1。
- `candidate-v2/export.json`：83份源码/180份public资源冻结，20份真实GET props经真实Rails layout/helper渲染生产构建，仅更新envelope version。与完整CI后的源码、资源一致；25个遗留旧hash没有被当前manifest引用，也没有浏览器实际请求。
- `notice-candidate-v2/`：五种IssueNotice十宽及四种SourceState在375/1440，共58组自然生产构建；全文、字体、逐字符Range和动作/容器几何完整保留。正式V1→V2逐字段相同；main→最终只有上述两条长句断行与0.5–1px行盒高度变化，来源级状态不变、横向溢出0。
- `help-candidate-v2/`：52个真实状态/宽度上下文，60入口均104×44、13px，274560个目标像素实心；175500个备注字框点和287760个禁用按钮点均无帮助链接侵占。18条自然Tab/Enter路径、162次帮助可信点击及33次实际gap中部可信点击通过。仅告警/仅备份各保留另一入口，部分配置两入口，完整配置无入口；Sources空/停用、收藏摘要/译文缺省与成员缺期作为控制。
- `print-review/`：两组main/最终A4 PDF共四页已实际栅格化逐页检查，均单页、无新增裁切；各对打印文本及目的链接一致。只规范化两个自有loopback端口，外链原样比较；不是像素完全相同或生产打印证明。

最初直接运行脚本误用了系统Ruby；其后未带CI导致Vite开发服务误判，均保留环境失败日志。初次帮助原生点检也有失败：前一个hash跳转的异步滚动在采样下一点时才到达，点击前命中链接、点击时scrollY从881变3230。确认Inertia的null-popstate→Scroll.reset→setTimeout锚点链路后，用帧/宏任务屏障和真实目的滚动位置等待解决测试竞态，没有改产品焦点行为或加固定sleep。初名system-green的日志实际上失败；system-final-green仅为V1，最终接受system-v2-green。

V1 `.field-note > a` 的52组中36组严格备注保护失败，保持失败原判；基线也能复现同一不足1px邻接命中带。最终分开flex项后备注/按钮仍按完整字框逐点严格保护，没有边界豁免。空白gap另列：45408个原始采样点中1450点处于Chrome不足1px的anchor外缘命中带；距链接至少1px的43958个核心点均不命中，中部可信点击也不跳转。不能写成“整段gap零命中”；旧全gap零断言的preflight失败保留。

最终notice服务端1338个请求均为GET/200；帮助矩阵浏览器1629个请求均为GET，其中68次假头像在IO前阻断，notice另有60次同类预期阻断。自有loopback无404/pageerror；29个帮助页和24个notice页实际Vite资源均属当前manifest。旧notice包的Inspector根路径404已单独定位并保留，最终服务路径正确。当前是自有headless Chrome的本地候选验收，未借此声称用户Chrome、其他浏览器、生产或整站奖项通过。远端门禁与提交归属由独立PR交付收据记录。
