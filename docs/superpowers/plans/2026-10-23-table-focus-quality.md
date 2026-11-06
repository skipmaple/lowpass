# 响应式管理表格的键盘位置恢复

> **For agentic workers:** Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** 跨1024/1025px时保留同一行的键盘位置与可见操作上下文。

**Architecture:** 保持现有单套桌面表格/手机列表。媒体变化前仅捕获表内焦点的稳定row.key与显式动作键，提交新分支后恢复对应控件，必要时打开其details祖先。动作消失/禁用时回同一行可用入口；只读行没有入口时程序聚焦该行（tabIndex=-1），不增加正常Tab停点，不抢表外焦点。

**Tech Stack:** 既有React hooks、原生HTMLElement/details/focus、Vitest与真实Chrome系统测试。

**Spec:** MVP PRD §6.4；award-quality-design的键盘/可见焦点检查。已有Sources七个跨断点失败和两个不跨对照：notice-help-quality/next-table-focus/independent-20261023/。

## Global Constraints

- 从main c1f4795独立分支修复，不折入PR69–79、不合并部署。
- 不重写视觉结构、不添加双份控件、新视觉值或依赖；沿用当前断点、顺序和原生语义。真实蓝色UA焦点反例后，复用现有2px墨色/2px偏移焦点样式覆盖Table根/行/empty与两布局summary。
- 仅本地fixture/自有浏览器验证，无真实业务动作、模型、OAuth或生产写入。
- 稳定动作键在各row内唯一，不靠显示文案、行序号或可聚焦nth定位。

## Review Focus

- 忙态文案/disabled与条件动作增减不能将焦点恢复到另一动作。
- 原焦点在closed details的子项时，恢复必须先让其祖先可见；summary自身不应被自动展开。
- Users和成功Runs桌面行没有控件，不能退到首行或BODY。
- 焦点在表外、被其他控件接管、不跨断点时不抢焦点。
- 行顺序变化按row.key，原行移除时只回本Table上下文，不跳其他行。

### Task 1: 恢复契约与真实回归

**Files:** Table.test.tsx、各管理页已有测试、test/system/table_focus_test.rb。
**Interfaces:** 断点事件通过matchMedia；真实焦点/原生Tab断言，不断言mock自身；每个已知动作data-table-focus键唯一。

- [x] 写双向第二行编辑、嵌套操作、summary消失只读fallback、表外和重排/目标禁用回归；9个真实RED，补充summary原open状态与fallback handler接管的独立RED。
- [x] 写真实Rails/React系统回归：Sources双向编辑/下一Tab与测试子项、Users只读summary消失。
- [x] 运行系统RED，3/9 assertions、3 failures、0 errors，确认焦点到BODY而非环境错误。

### Task 2: 局部实现与验收

**Files:** app/frontend/components/Table.tsx；Admin/Sources/Index、Admin/Sources/Runs、Admin/Issues/Index的动作属性；tokens.css沿用既有focus规则。
**Interfaces:** 以row.key+data-table-focus恢复；Table自有summary键table-details；可用性检查排除disabled/hidden/inert，fallback不展开无关details。

- [x] 最小实现，最终16项前端、3/35真实系统GREEN；独立完整diff评审的P2经RED/GREEN修复并复审。蓝框预检失败也有真实RED→墨2px GREEN及独立复审。最终V3完整CI467/856/80通过、首屏264.61KB。
- [x] 完整bin/ci、首屏预算；冻结85源/181public/5真实GET页面；13场景以12原样通过+1纠正真实props预期后定向通过收口，51次Table焦点的原生AX/墨2px/可见性证明保留。
- [ ] 保留失败尝试、资源归属和原始证据，更新品质轮次，独立Draft PR及最新远端门禁。

## 本轮判断

沿用用户的持续自检修复授权与现有键盘契约；这是已复现缺陷的局部恢复，不新增产品流程。读取依赖复制尚未完成时的首次前端启动错误单独保留，不能当产品RED。
