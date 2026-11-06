# M2 原生输入本地候选

2026-10-24。依据已批准的完整 `docs/superpowers/specs/2026-10-24-live-page-input-design.md`；该提案原文保留。仅本地实现与回归，不代表首帧视觉总验收、物理手机或生产结果。

## 可见契约

NEW 在最终坐标淡入，不横移；OLD 完整视口沿原方向退出 24px 并淡出，普通跨页 240ms、换期 360ms。报头静止；旧日期保留自身尺寸，放在新日期的位置交替。新页无日期时旧日期留在旧位置淡出，新页无报头时旧报头随同次时长淡出。

真实 pointerdown、keydown、wheel 在播放期间同步结束视觉反馈；不拦截默认动作、不改变几何、不重放事件、不调用控件 focus/click、不设 pointer capture。自动导航焦点不会结束动画，读者已进行真实输入时待执行的导航 focus 不得抢回焦点。

## 实现边界与技术裁定

服务端 beforeUpdate 只记录 Page。track 消费唯一目标，Layout/Login 的 layout effect 只对同一 Page 对象切换 NEW，首次挂载与 StrictMode 均幂等。NEW 的 root/masthead/date 三名都为 none；全部原生伪层不参与命中。未匹配、重叠、跳过、拒绝均由独立 token 收尾，不回退到 URL 匹配。客户端 props replace 不新增过渡。既有 historyScroll 的快照和 replay 产品逻辑保持不变。

提交即设置 NEW opacity0 和临时纸面，复制现有外层两层纹理并按边框差对齐相位。ready 同步定位旧日期并创建 NEW Animation。Chrome 在 VT.ready 时原生 OLD 仍可能 pending/startTime=null；同 timeline 立即 play NEW，让同一次 UA animation update 设置两者起点，再严格核对两者真实 startTime 相等。若原生起点已经可读则直接采用；不使用 rAF/timer 自造时间。API 异常或起点不同即收尾显示终态。临时样式精确恢复。

导航焦点原有晚到 rAF 在可信账户点击之后曾把菜单焦点抢回 h1；对应 RED 和真实事件链保留。最小联动是在真实输入后撤销该次待执行自动 focus，正常导航焦点和原 pathname 判断保留。

## 本地证据与未验项

本地 SDD 证据目录 `.superpowers/sdd/2026-10-24-live-page-input/` 的 `implementation-batch-report.md` 列出命令、红绿、技术裁定与提交。测试在隔离 PostgreSQL18 和 headless Chrome 中执行，输入来自 CDP Input，触摸为 Chrome 触摸模拟，不能称物理设备。

回归覆盖同一 Page 提交、真实 adapter、严格 native timeline/startTime、正文几何、临时纸面相位、可信搜索光标/输入、账户焦点/Escape/拖出取消、正文拖选、收藏、修饰键链接、wheel、触摸 tap/pan cancel，以及 replace、Login redirect、skip、reject、交错 token 和历史。修饰键链接将测试目标换为本机 health，避免外网访问；它只证明原生新窗口默认动作。

原 Tracing Screenshot 探针和原生阳性对照均缺绘制层，不能把那组图当首个实际可见 paint 的通过或失败依据。严格相同起点是机制证据，JS 首 rAF 不是可见 paint。自然首帧旧图/日期、既有周刊真实图片 multiply、全部长短页/页脚与桌面浏览器矩阵由 Task5 独立验收；未通过不得发布。完整 CI 由 root 在独立依赖安全更新 rebase 后执行。

## 报头纸底遮盖修正（独立验收追加）

独立验收发现：即使 OLD masthead 隐藏，OLD root 的纸底仍把真实 NEW 报头染浅。两次真实 Rails 应用自然播放截图确认该问题，375/1440 的报头背景早帧分别为 RGB134,132,127 与99,98,94，正常前后均29,29,27。原始记录保存在本地授权证据 `m2-app-layer-failure/`，不覆盖原报告；截图区间跨多个自然帧，不能据此声称精确首paint已覆盖。

最小修正在 VT.ready 读取新报头实际 bottom（移动端换行报头104px，不能硬编码56px），保留小数并限制于视口0..height。在静止的 root group 上用 inset 裁掉该满宽区域，让真实 NEW 报头可见。OLD root 子图继续±24px退场，裁剪不会跟着移动；独立 OLD日期组不裁。页脚旧报头不在视口时仍读取新报头；Login 无新报头时不裁。裁剪变量随本 token 收尾，旧 token 不得清新 token。该修正沿用已批准可见契约。

修复后同两组实际应用样本保存在 `m2-app-layer-fix/`：baseline、6次自然截图、final 的3个无字报头背景采样点全部保持 RGB29,29,27。新增单元在修复前4失败、修复后相关83通过；双向360/页脚/独立日期/Login裁剪回归通过。精确首paint覆盖仍未成立，不能把这一窄项像素修复扩写成M2总验收。
