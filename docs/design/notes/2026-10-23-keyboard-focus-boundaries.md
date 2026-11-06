# 菜单与对话框的键盘焦点边界

实际 Chrome 155 验收发现三处键盘缺陷，375px 与 1440px 均可重复。验收使用真实 production module 与 Rails helper / layout，仅以冻结 props 和内存响应替代业务数据、写请求；相关组件源码与 main `c1f47954` 相同。

1. 「重抓某源」打开后，Shift+Tab 进入默认来源，ArrowDown 选择第二来源，再 Shift+Tab，焦点变成 BODY，页面失焦。弹窗仍打开，背景仍保持 inert。由确认按钮按 Tab 则会聚焦未选中的第一来源。
2. 兴趣画像删除失败、按钮恢复后，焦点仍在纸卡本身。首个 Shift+Tab 同样离开弹窗。
3. 账户按钮 ArrowDown 打开菜单时，先聚焦「账户信息」，同一次按键又移动到「收藏」；ArrowUp 则先到「登出」再到前一项。现有 jsdom 首尾测试通过，真实键盘事件仍能触发重复处理。

## 修正

Dialog 每次 Tab 都重新读取单选组的 checked，按非空 name 与 form owner 取当前代表项，再判断首尾。没有 checked 时取该组首项；当前选源页总会预选一个来源。组内箭头和中间 Tab 继续由浏览器处理。焦点在纸卡本身时，Tab 进入首项，Shift+Tab 进入末项；busy 全禁用期间仍停在纸卡。

账户按钮在已处理打开方向键后停止该事件冒泡，避免刚挂载的 document 监听再消费同一按键。菜单打开后的方向键、Home / End、Escape 与点击行为保留。

上述停点对应 [APG radio](https://www.w3.org/WAI/ARIA/apg/patterns/radio/)、[modal dialog](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) 和 [menu button](https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/) 的键盘约定。radio 的 name、form owner 与树关系以 [HTML 定义](https://html.spec.whatwg.org/multipage/input.html#radio-button-state-(type=radio)) 为依据；本轮查询始终在同一纸卡的普通 DOM 内。

## 回归证据

- 现有 Dialog 五项单测先通过。新增实际选源页面与 busy 恢复测试后，旧源码为 2 failed / 16 passed：选中第二来源后的反向 Tab、busy 恢复后的反向 Tab 均失败。修正后连同既有 Masthead 为 35 passed。
- 原生系统回归在旧源码分别失败于菜单开场落到「收藏」、已选来源反向 Tab 离框。首次命令使用 `test:system`，该任务运行了全部 79 项，只有两项新测试失败；原始结果保留。修正后用定向命令 `bin/rails test test/system/keyboard_focus_test.rb`，2 项 / 19 assertions 全部通过。
- 初次新增的跨 form 中间 Tab 断言发现 Testing Library 按全局 name 剪裁 radio，未区分 form owner。该断言不能证明产品缺陷，已撤回并保留日志；保护用例改为检查 Dialog 自身绕回的首停点，另覆盖无名 radio 的独立性。
- 完整 `bin/ci` 一次退出 0（63.27 秒）：459 项前端、856 项 Rails（3763 assertions）、79 项系统（8063 assertions）。首屏 264.57 KB / 300 KB；现有两项 Vitest moderate 告警保留，high 门禁通过。application CSS 与 c1f production 基线逐字节一致。

## Production 包重放

- 候选独立基于 c1f，使用 CI 产物和实际模板；基线浏览器材料来自 PR #73，两版被测键盘组件的源字节相同。各自使用其实际字体入口，本轮只对键盘行为作归因。
- 选源与普通确认框共八个上下文：375 / 1440，各含原三条轨迹及第三来源的实时改选。焦点逸出均为零；第二、第三来源双向绕回当前 checked 项，Tab 不改变选择。取消初始焦点、Escape 返回触发点、inert 与 overflow 恢复通过。六对初始弹窗 PNG 逐字节相同。
- 收藏与后台设置共四个上下文。首次 ArrowDown / ArrowUp 分别只聚焦一次首项 / 末项；菜单内方向键、Home / End、Escape 保持有效。删除失败后首次反向 Tab 进入确认，另一次失败后的首次正向 Tab 进入取消；busy、失败取消返回、自定义成功标题返回均通过。收藏取消 / 恢复及故意失败回滚保持正确焦点，失败 status 超过 5.2 秒仍显示。
- 选源脚本即时取样曾读到纸色轮廓，不能据此判断稳定焦点不可见。两宽各补一个原三键单例：不改焦点或 CSS，仅只读 CSSOM 并让样式正常更新，随后均为源码定义的 2px 墨色轮廓、2px 间距，稳定 PNG 实际可见。原即时值与截图保留；不把额外等待时长解释为焦点必须延迟出现。
- 页面脚本错误和外部 / 非预期请求均为零；写请求全部内存应答。两套基线和候选原始材料分别保留，自建浏览器与服务已关闭。独立审查接受产品 diff、失败 / 通过日志及基线来源，候选原始证据另作收尾复核。

## 边界

通用隐藏元素、继承禁用与正 tabindex 的顺序需要单独验证；本轮覆盖现有弹窗控件组合，不扩大原有选择器的能力声明。用户 Chrome、Firefox 和生产验收仍待完成，本地单次轨迹不证明所有浏览器或辅助技术环境。

未部署、未调用模型、未修改已发布内容或真实业务记录。完整 CI 沿用测试库 fixture / seed；浏览器中的收藏与后台提交仅由内存夹具应答。收藏故意失败时的 500 控制台消息属于所测失败响应，不是页面脚本错误。早期返回全 props 的夹具导致删除成功标题返回超时，改用真实 partial 协议后通过，未把该超时当作产品缺陷。
