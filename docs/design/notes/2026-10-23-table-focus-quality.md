# 管理表格跨断点的键盘位置

本轮从main `c1f47954b56f4d8c08d58f02a9beab0ee61b8081` 独立修复，不折入待合并PR69–79，不合并部署，不代表整站获奖品质已经达标。契约依据PRD §6.4的键盘可达、焦点可见，以及品质清单的键盘位置保持。

## 实际缺陷与修复

旧Table在1024↔1025px切换两棵互斥DOM树。真实Sources GET的7个跨断点样本全部卸载原焦点与行节点，焦点落到BODY，下一Tab回首行；2个不跨断点对照保留第二行与下一Tab的记录入口。测试抓取子按钮还失去展开祖先。旧证据保持封存：`notice-help-quality/next-table-focus/independent-20261023/`。

继续保持单套桌面表格/手机列表。媒体变化前只捕获表内焦点的稳定row.key、动作键和focused summary的展开状态；layout effect提交后恢复同一行同一动作，必要时打开其details祖先。各调用方明确标记动作键，不猜文案、行号或可聚焦nth，因此忙态文字、禁用及重排不会错认身份。

原目标消失或原生禁用时回同一行首个实际可用入口；Users和部分Runs没有入口时聚焦该行tabIndex=-1，不新增正常Tab停点。原行被同批数据移除则只回本Table上下文，不跳到另一行。表外焦点保持；提交前的新表内选择更新恢复位置；提交后focus handler接管时立即尊重它。快速同批往返不留下旧恢复请求。精确恢复只打开原目标所需祖先，不记全表展开状态或解除hidden/inert/disabled。

V2真实Users预检还发现行fallback使用Chrome默认蓝色1px描边。它虽有DOM/AX焦点，却不符合既有视觉令牌；保留失败样本，不把`:focus-visible`当绘制通过。最终仅扩展已有2px var(--ink)、offset2焦点规则到Table根/行/空态和两种布局内summary，修掉新fallback及原生summary的UA蓝框，不改变尺寸、布局、普通Tab顺序或无焦点外观。

## 测试与独立评审

证据根目录：`/Users/drewlee/.codex/visualizations/2026/10/22/01a162a8-dbb7-7583-bab0-a4e6384d008a/table-focus-quality/`。

- `frontend-red-confirmed.log`：13项中9失败、4通过，焦点/展开/只读行等真实行为失败。补充focused summary open状态先有2失败/13通过，再修复。
- `system-red.log`：真实Rails/React/Chrome，3 runs、9 assertions、3 failures、0 errors，均为分支卸载后的BODY焦点。`system-green-attempt1.log`仅为焦点逻辑V1的3/33通过；补充颜色/线宽回归后 `row-outline-red.log` 为1/6、1个真实蓝框失败，最终 `system-v3-green.log` 3/35通过。
- `code-review/report-v1.md`：独立评审发现fallback入口的focus handler转移焦点后，旧循环仍聚焦下一入口；当前调用方没有该handler，不能声称线上已触发。独立repo外最小复现与repo内 `fallback-handoff-red.log` 均实际RED。
- `frontend-v2-green.log`：最终16项通过；`code-review/v2-followup.md`：该P2已修复，独立原复现GREEN、相关调用页22项与TypeScript通过，源SHA固定。V1 finding与失败保留，不改判。
- `full-ci-v3.log`：最终前端467、Rails856/3763 assertions、系统80/8079 assertions全绿；首屏264.61KB≤300KB，总58.11秒。先前full-ci/full-ci-v2只代表各自版本。
- `candidate-v3/export.json`：最终85份源码/测试与181份public冻结，五份真实GET由真实Rails layout/helper渲染当前生产构建，仅更新envelope version；数据库端口1禁用，不以手造props补状态。旧candidate保留为V2，未覆盖其蓝框失败。
- `code-review/v3-style-review.md`：只读复审焦点规则范围、既有令牌与新增真实系统断言，未发现新的必须修复问题；Table与前端测试SHA保持V2，视觉仍以最终自然浏览器验收为界。
- `additional-inputs/`：147条断言一次通过，补齐Users两只读行、Runs成功与164字长错误、Issues已发布/缺期/不可用理由、账户页非空头像四份真实控制器GET。独立临时PostgreSQL18库事务回滚、22张表计数恢复并DROP后独立查询确认不存在；默认testDB未连接，源/资源/旧输入摘要不变。账户输入供另一项自然头像诊断，不扩当前修复。

首次前端启动早于依赖复制完成，缺sourcemap-codec的环境错误单独保留；复制完成后基线454通过。手动Vite测试构建未指定RAILS_ENV时输出vite-dev，不能当生产冻结资源；实际系统测试由test环境加载/构建，最终bin/ci按配置显式构建生产与test两套资源。本轮不把环境失败当产品RED，也不将V1通过冒充最终验证。

## 最终候选浏览器验收

`browser-acceptance/final-summary.json`：Sources原9个跨/不跨对照加表外控制、Users只读行、Runs长错误及Issues查看入口，共13个独立场景。原13矩阵12个原样通过；Issues最后的下一Tab预期误含weekly不存在的refetch，真实冻结props为 `refetchable_sources=[]`、`reasons=null`，故下一入口应是 `/weekly/2026-W36` 的查看。只修正该独立预期后定向1项通过；原exit1/script/raw保持失败，不为汇总重跑已通过12项。

55个接受阶段中51个实际Table焦点均为solid 2px、rgb(29,29,27)、offset2，AX实际DOM backend节点focused、同row/action与视口内可见。第二行编辑后下一Tab仍到本行记录；more原closed/open状态、子按钮可见祖先与后续Tab均正确；不跨断点保留同节点，表外焦点不抢。Users无入口时聚焦同一只读行，tabIndex=-1不增加正常Tab停点；其最后一行后的自然Tab可合法绕回跳正文，不能误报焦点丢失。Table外skip-link原UA描边另保留，不声称全站focus都已统一。

370个浏览器请求全GET，14个预期假头像在IO前阻断，26个实际Vite资源均属当前manifest；无非预期HTTP/console/pageerror。动作键全标且row内唯一，业务按钮只聚焦未执行。原V2蓝框、V3预检把closed summary自身误当必须展开祖先的harness错误、原Issues错误预期均保留，分别写清产品反例与测试条件错误。全部资源关闭；最终冻结源与资源未变。

root另实际查看第二行编辑、展开more、只读用户行、Runs错误summary及Issues最后查看入口截图，墨色焦点可辨且无裁切。上述证明范围为自有headless Chrome155与真实fixture GET，不能替代用户Chrome、其他平台、生产或整个品质目标。
