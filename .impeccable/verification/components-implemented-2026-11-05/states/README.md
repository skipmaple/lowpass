# 三主题组件状态复验

- 真实页面：`http://127.0.0.1:3000/admin/sources/new`，独立 Chrome，1440 × 1000，三个主题逐个加载真实前端。脚本见 `check-states.cjs`，量测见 `states.json`。
- 网络边界：允许 GET / HEAD；所有其他请求均拦截。每个主题仅出现一条 POST `/admin/sources`，没有转发。浏览器延迟该请求以观察 pending，再模拟 Inertia 校验错误和错误 flash。此项验证前端状态呈现，不代表后端校验集成验收，也未创建来源或触发抓取。
- 没有修改浏览器 CSS / DOM 来制造状态。
- pending：字段和选项禁用；保存按钮显示“正在保存…”、`aria-busy=true`、wait 光标；所有主题使用各自等待态颜色。后续保存按钮稳定宽度复验由主代理汇总。
- invalid：首个错误字段自动获得焦点，焦点环与 2px 边框一致使用主题错误色；A 为 #9C3E2C，B 保留黑白，C 为 #E6A18B。错误说明、图标和 toast 同色且可见。首次复验发现 A/C 聚焦内框回到品牌色，主代理修正后本目录截图和 JSON 已更新。
- readonly：真实“阮一峰周刊”固定仓库字段 ruanyf/weekly 保持虚线、浅层背景，可聚焦并选择文字；不可编辑。
- disabled：在全新页面（模拟回包前）切换“阮一峰周刊”，三主题均日刊禁用且未选中、周刊可用且选中。等待 300ms 过渡结束后测量，排除了过渡帧误报。
- 三次执行均无 pageerror。

每个主题有 pending、invalid-toast、readonly-disabled 三张实际截图，共九张。独立 320 / 768 响应式检查由另一验收代理记录。
