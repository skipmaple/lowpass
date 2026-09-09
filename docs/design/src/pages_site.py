"""第十轮：周刊、归档、搜索、登录、设置、管理后台。全部复用第九轮的令牌与装置，不新造颜色、字号与线宽。"""
import re
from common import *
from pages_warm import doc
from pages_press import ill_sunrise
from pages_front2 import (GROUND, PAPER, INK, INK2, GREEN, RULE, NAME, SERIF, KAIF, MONOF, FONTS, css, mixed, mono2, ctrl, masthead, sheet, foot_link)
from pages_front3 import chip, PAPER_DIM

CJK = re.compile(r'([⺀-鿿＀-￯]+)')

# ---------- 文字与小件 ----------

def kai(text, size=15, color=INK, extra=''):
    return '<span style="font-family: ' + KAIF + '; font-size: ' + str(size) + 'px; color: ' + color + ';' + extra + '">' + text + '</span>'

def txt(text, size=15, color=INK, weight=400, extra=''):
    """内容文字：中文文楷，拉丁 Newsreader。"""
    out = []
    for run in CJK.split(text):
        if not run:
            continue
        if CJK.fullmatch(run):
            out.append('<span style="font-family: ' + KAIF + '; font-size: ' + str(size) + 'px; color: ' + color + ';' + extra + '">' + run + '</span>')
        else:
            out.append('<span style="font-family: ' + SERIF + '; font-size: ' + str(size) + 'px; font-weight: ' + str(weight) + '; color: ' + color + ';' + extra + '">' + run + '</span>')
    return '<span>' + ''.join(out) + '</span>'

def link(text, size=15, color=INK):
    return '<a href="#" class="t" style="font-family: ' + KAIF + '; font-size: ' + str(size) + 'px; color: ' + color + ';">' + text + '</a>'

def hrule(w=1, margin='0'):
    return '<div style="height: ' + str(w) + 'px; background: ' + INK + '; margin: ' + margin + ';"></div>'

def btn(text, primary=False, il=None, ir=None, h=40, off=False):
    if primary:
        return ('<span style="display: inline-flex; align-items: center; gap: 8px; height: ' + str(h) + 'px; padding: 0 16px; background: ' + INK + '; color: ' + PAPER + '; white-space: nowrap;">'
                + (icon(il, 14, PAPER) if il else '') + kai(text, 15, PAPER) + (icon(ir, 14, PAPER) if ir else '') + '</span>')
    return ctrl(text, il=il, ir=ir, off=off, h=h)

def seg(options, active, h=40, size=15):
    """分段控件：并排描边块，当前项反白。文字按语言分配字体。"""
    out = []
    for i, o in enumerate(options):
        on = o == active
        st = ('display: inline-flex; align-items: center; height: ' + str(h) + 'px; padding: 0 14px; border: 1px solid ' + INK + '; white-space: nowrap;'
              + (' background: ' + INK + ';' if on else '') + (' margin-left: -1px;' if i else ''))
        out.append('<span style="' + st + '">' + txt(o, size, PAPER if on else INK, 500) + '</span>')
    return '<span style="display: inline-flex;">' + ''.join(out) + '</span>'

def chip_outline(text, on=False):
    if on:
        return chip(text)
    return ('<span style="display: inline-flex; align-items: center; height: 22px; padding: 0 8px; border: 1px solid ' + RULE + '; letter-spacing: 0.04em; white-space: nowrap;">' + txt(text, 12, INK2, 500) + '</span>')

def field(label_text, value='', placeholder='', mono=False, width='100%', note=None):
    inner = (mono2(value, INK, 13) if mono and value else (kai(value, 15) if value else kai(placeholder, 15, INK2)))
    return ('<div style="display: flex; flex-direction: column; gap: 6px; width: ' + width + ';">' + kai(label_text, 13, INK2)
            + '<div style="display: flex; align-items: center; height: 40px; padding: 0 12px; border: 1px solid ' + INK + ';">' + inner + '</div>'
            + (kai(note, 13, INK2) if note else '') + '</div>')

def mark(kind):
    """归档与期列表的状态记号：已发布实心、空刊描边、缺期叉。"""
    if kind == 'ok':
        return '<span style="display: inline-block; width: 10px; height: 10px; background: ' + INK + ';"></span>'
    if kind == 'empty':
        return '<span style="display: inline-block; width: 10px; height: 10px; border: 1px solid ' + INK + '; box-sizing: border-box;"></span>'
    return icon('x', 12, INK2)

def table(headers, rows, widths):
    """1px 线表格：表头文楷 12 次墨，单元格自带字体。"""
    cols = ' '.join(widths)
    head = '<div style="display: grid; grid-template-columns: ' + cols + '; gap: 0 16px; padding: 0 0 10px 0; border-bottom: 1px solid ' + INK + ';">' + ''.join('<span>' + kai(h, 12, INK2) + '</span>' for h in headers) + '</div>'
    body = ''.join('<div style="display: grid; grid-template-columns: ' + cols + '; gap: 0 16px; align-items: center; padding: 14px 0; border-bottom: 1px solid ' + RULE + ';">' + ''.join('<span style="min-width: 0; display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">' + c + '</span>' for c in r) + '</div>' for r in rows)
    return head + body

def page_head(big, top=None, bottom=None, right='', compact=False):
    """通用期头：大字（文楷）在左，右侧叠放两行小字，右端放控件；底线 2px。"""
    size, bsize = (40, 15) if compact else (56, 20)
    stack = ('<div style="display: flex; flex-direction: column; gap: 6px; padding-bottom: 4px;">' + (mono2(top, INK2, 13) if top else '')
             + (kai(bottom, bsize, INK2, ' line-height: 1;') if bottom else '') + '</div>')
    return ('<div style="display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; padding: ' + ('24px 0 16px 0' if compact else '32px 0 20px 0') + '; border-bottom: 2px solid ' + INK + ';">'
            '<div style="display: flex; align-items: flex-end; gap: 16px;"><span style="font-family: ' + (KAI if CJK.search(big) else SERIF) + '; font-size: ' + str(size) + 'px; ' + ('' if CJK.search(big) else 'font-weight: 600; ') + 'line-height: 1;">' + big + '</span>' + stack + '</div>'
            + right + '</div>')

def controls(prev, nxt, mid='归档', h=40):
    return '<div style="display: flex; gap: 8px; align-items: center;">' + ctrl(prev, il='chevron-left', h=h) + ctrl(mid, h=h) + ctrl(nxt, ir='chevron-right', off=True, h=h) + '</div>'

def footer_site(note, link_text, right=''):
    stamp = ('<svg viewBox="0 0 64 64" width="48" height="48" fill="none" stroke="' + INK + '" stroke-width="1.6" style="display: block; flex: none;"><circle cx="32" cy="32" r="29"></circle><circle cx="32" cy="32" r="23" stroke-dasharray="3 3" stroke-width="1"></circle>'
             '<text x="32" y="37" text-anchor="middle" font-family="Bodoni Moda, serif" font-size="15" font-weight="700" fill="' + INK + '" stroke="none">LP</text></svg>')
    return ('<div style="border-top: 2px solid ' + INK + '; margin-top: 36px; padding: 18px 0 8px 0; display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap;">'
            '<div style="display: flex; align-items: center; gap: 16px;">' + stamp + '<div style="display: flex; flex-direction: column; gap: 6px;">' + mono2(note) + link(link_text) + '</div></div>' + right + '</div>')

def item(rank, title, summary, compact=False, meta=None):
    """周刊条目：序号、标题、摘要。产品负责人定（D19）：阮一峰周刊的内容不加模型生成的推荐理由，也就没有兴趣标签。"""
    title_html = '<a href="#" class="t" style="font-family: ' + KAIF + '; font-size: 20px; line-height: 1.35;">' + title + '</a>'
    sec = '<span style="font-family: ' + KAIF + '; font-size: 15px; line-height: 1.7; color: ' + INK2 + ';">' + summary + '</span>'
    meta_html = ('<div>' + mono2(meta) + '</div>') if meta else ''
    if compact:
        return ('<div style="padding: 20px 0; border-bottom: 1px solid ' + RULE + ';">' + mono2(str(rank)) + '<div style="margin-top: 8px;">' + title_html + '</div><div style="margin-top: 8px;">' + sec + '</div>' + meta_html + '</div>')
    return ('<div style="display: grid; grid-template-columns: 40px minmax(0, 1fr); gap: 16px; padding: 18px 0; border-bottom: 1px solid ' + RULE + ';">'
            '<span style="padding-top: 5px; font-family: ' + MONOF + '; font-size: 13px; color: ' + INK2 + ';">' + str(rank) + '</span>'
            '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0;">' + title_html + sec + meta_html + '</div></div>')

# ---------- 示例数据（虚构） ----------

WEEKLY = {'week': '第 36 周', 'year': '2026', 'range': '8月31日 至 9月6日', 'src': '阮一峰科技爱好者周刊', 'issue': '第 366 期', 'topic': '慢下来的理由'}
SECTIONS = ['本周话题', '科技动态', '文章', '工具', '资源', '图片', '文摘', '言论']
WEEKLY_ITEMS = {
    '本周话题': [('慢下来的理由', '作者谈为什么把每周的写作节奏从三篇降到一篇，以及慢下来之后读者反馈的变化。', '开发者效率', '与开发者效率相关：讨论节奏与产出的取舍，和每日摘要"少即是多"的思路一致。')],
    '科技动态': [('一块 3 美元的 RISC-V 开发板开始量产', '国产 RISC-V 芯片厂商推出面向教学的开发板，带 Wi-Fi 与 20 个 GPIO。', '嵌入式', '嵌入式命中：低成本 RISC-V 板子适合做传感器节点的实验平台。'),
                 ('浏览器原生支持 CSS 锚点定位', 'Chrome 与 Safari 相继支持 anchor positioning，弹出层不再需要 JavaScript 计算位置。', '前端开发', '前端开发相关：浏览器 API 的新能力，能省掉一类定位库。'),
                 ('欧洲电网测试用电动车电池做储能', '试点项目把停车中的电动车电池接入电网削峰，参与车辆约两千辆。', '电子机械', '与电子机械与自动化相关度中等：电池管理与并网控制的工程案例。')],
    '文章': [('为什么单文件数据库又流行了', '从 SQLite 到 DuckDB，作者梳理单文件数据库在本地优先应用里重新受欢迎的原因。', '后端架构', '后端架构相关：单文件数据库的取舍，和你关注的 SQLite 话题呼应。'),
             ('我给家里的所有插座装了功率计', '用 ESP32 与霍尔传感器自制功率计，接入 Home Assistant 看每个电器的用电曲线。', '智能家居', '命中智能家居与嵌入式：ESP32 加 Home Assistant 的完整做法，可直接复刻。')],
    '工具': [('一个终端下的日志工具', '按字段折叠、着色和过滤 JSON 日志，单个二进制文件，支持管道输入。', '开发者效率', '开发者效率：终端日志工具，与本周 Hacker News 上的同类项目可对比。'),
             ('把 Markdown 表格转成图表的命令行', '读入 Markdown 表格，输出 SVG 折线或柱状图，适合写周报。', '开发者效率', '开发者效率：命令行小工具，写文档时省事。'),
             ('开源的 PCB 走线检查器', '读取 KiCad 文件，检查走线宽度、间距与阻抗，在浏览器里跑。', '硬件设计', '硬件设计命中：PCB 检查工具，做板子前多一道自动校验。')],
}
SEARCH_Q = '终端 工具'
SEARCH_HITS = ['终端', '工具']
SEARCH_RESULTS = [
    ('周刊', '阮一峰周刊', '第 36 周 · 工具', '一个终端下的日志工具', '按字段折叠、着色和过滤 JSON 日志，单个二进制文件，支持管道输入。', '9月4日'),
    ('周刊', '阮一峰周刊', '第 34 周 · 工具', '终端里的 Markdown 预览工具', '在终端直接渲染 Markdown，代码块高亮，支持 iTerm 图片协议。', '8月21日'),
    ('周刊', '阮一峰周刊', '第 33 周 · 文章', '用 tmux 把终端变成工作台', '把常用的监控、日志与编辑窗口固定成一套布局，一条命令恢复。', '8月14日'),
    ('周刊', '阮一峰周刊', '第 31 周 · 工具', '终端文件管理器 yazi 的配置笔记', '预览图片和 PDF，自定义快捷键，替代桌面文件管理的工作流。', '7月31日'),
]
DAYS = [('9月8日', '星期二', 'ok', '06:12 发布', 'HN 10 · GH 10 · HAD 10'), ('9月7日', '星期一', 'ok', '延迟生成于 07:05', 'HN 10 · GH 0 · HAD 失败'), ('9月6日', '星期日', 'ok', '06:11 发布', 'HN 10 · GH 10 · HAD 10'),
        ('9月5日', '星期六', 'empty', '空刊', 'HN 失败 · GH 失败 · HAD 失败'), ('9月4日', '星期五', 'ok', '06:12 发布 · 已于 06:42 修订', 'HN 10 · GH 10 · HAD 10'), ('9月3日', '星期四', 'missing', '缺期', ''),
        ('9月2日', '星期三', 'ok', '06:12 发布', 'HN 10 · GH 10 · HAD 8'), ('9月1日', '星期二', 'ok', '06:13 发布', 'HN 10 · GH 10 · HAD 10')]
WEEKS = [('第 36 周', '8月31日 至 9月6日', 'ok', '阮一峰周刊 第 366 期 · 慢下来的理由', '42 条'), ('第 35 周', '8月24日 至 8月30日', 'ok', '阮一峰周刊 第 365 期 · 一个人的公司', '40 条'),
         ('第 34 周', '8月17日 至 8月23日', 'empty', '本周无内容', ''), ('第 33 周', '8月10日 至 8月16日', 'ok', '阮一峰周刊 第 364 期 · 我们为什么写博客', '38 条'),
         ('第 32 周', '8月3日 至 8月9日', 'ok', '阮一峰周刊 第 363 期 · 三十年前的互联网', '41 条'), ('第 31 周', '7月27日 至 8月2日', 'ok', '阮一峰周刊 第 361、362 期 · 补发与常规', '79 条')]
SOURCES_ADMIN = [('1', 'Hacker News', 'Hacker News', '日刊', '启用', 'ok', '正常', '9月8日 06:12 · 成功 · 10 条', '9月9日 06:00'),
                 ('2', 'GitHub Trending', 'GitHub Trending', '日刊', '启用', 'ok', '正常', '9月8日 06:12 · 成功 · 10 条', '9月9日 06:00'),
                 ('3', 'Hackaday', 'RSS/Atom', '日刊', '启用', 'ok', '正常', '9月8日 06:12 · 成功 · 10 条', '9月9日 06:00'),
                 ('1', '阮一峰科技爱好者周刊', '阮一峰周刊', '周刊', '启用', 'warn', '连续失败 3 次', '9月9日 09:00 · 失败 · GitHub API 403', '9月10日 09:00')]
ISSUES = [('日刊', '2026-09-08', '已发布', '06:12', 'HN 10 · GH 10 · HAD 10', 'ok'), ('日刊', '2026-09-07', '已发布 · 延迟', '07:05', 'HN 10 · GH 0 · HAD 失败', 'ok'), ('日刊', '2026-09-06', '已发布', '06:11', 'HN 10 · GH 10 · HAD 10', 'ok'),
          ('日刊', '2026-09-05', '空刊', '06:20', 'HN 失败 · GH 失败 · HAD 失败', 'empty'), ('日刊', '2026-09-04', '已发布 · 已修订', '06:12 / 06:42', 'HN 10 · GH 10 · HAD 10', 'ok'), ('日刊', '2026-09-03', '缺期', '', '', 'missing'),
          ('周刊', '2026-W36', '已发布', '9月4日 09:03', '阮一峰 42 条', 'ok')]
INTERESTS = [('嵌入式开发', 'ESP32、MCU、固件、RTOS'), ('AI / LLM', '本地模型部署、Agent 框架、语音 AI、ASR/TTS、RAG'), ('前端开发', 'React、Web 技术、浏览器 API'), ('后端开发', 'Ruby、Rails、Go、Python、服务端框架'),
             ('后端架构', '分布式系统、微服务、数据库、消息队列'), ('UI/UX', '设计工具、设计系统、交互设计、用户体验'), ('硬件设计', '电路、PCB、传感器、音频系统'), ('电子机械与自动化', '电机控制、PLC、机器人、自动化系统'),
             ('开发者效率', 'CLI 工具、编辑器插件、CI/CD、Git 工作流'), ('智能家居 / IoT', 'Home Assistant、MQTT、智能设备')]

# ---------- 周刊 ----------

RSS_WEEKLY = {'name': '命令行周报', 'meta': 'RSS · 本周 3 条', 'entries': [
    ('fzf 0.60 加了多列预览', '预览窗可以并排显示文件内容与 git diff，配合 ripgrep 的用法作者写了一段。', '9月5日 08:00'),
    ('一份 shell 启动速度的测量方法', '用 hyperfine 量化每个插件对启动时间的影响，结论是 nvm 占了一半。', '9月3日 07:30'),
    ('把 man 页转成可搜索的本地站点', '一个 200 行的脚本，输出静态 HTML 并带全文搜索。', '9月1日 09:10')]}

def source_band(compact=False, name=None, meta=None, link_text='原文'):
    name = name or WEEKLY['src']
    meta = meta or (WEEKLY['issue'] + ' · ' + WEEKLY['topic'])
    h = 56 if compact else 80
    return ('<div style="margin-top: 24px; height: ' + str(h) + 'px; background: ' + INK + '; display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 0 ' + ('16px' if compact else '24px') + ';">'
            '<div style="display: flex; align-items: center; gap: 14px; min-width: 0;">' + icon('book-open', 20 if compact else 28, PAPER) + kai(name, 20 if compact else 32, PAPER, ' white-space: nowrap; line-height: 1;') + '</div>'
            + ('' if compact else '<div style="display: flex; align-items: center; gap: 16px;">' + kai(meta, 15, PAPER_DIM) + '<a href="#" style="display: inline-flex; align-items: center; gap: 6px;">' + kai(link_text, 15, PAPER) + icon('arrow-up-right', 13, PAPER) + '</a></div>') + '</div>')

def rss_section(compact=False):
    """通用 RSS 周刊源节（F-08、R-2.4）：没有板块，按发布时间倒序，每条带发布时间。"""
    rows = ''.join(item(i + 1, t, sm, compact, meta=when) for i, (t, sm, when) in enumerate(RSS_WEEKLY['entries']))
    return source_band(compact, RSS_WEEKLY['name'], RSS_WEEKLY['meta'], '来源') + '<div style="margin-top: 16px; border-top: 1px solid ' + INK + ';">' + rows + '</div>'

def degraded_section(compact=False):
    """R-2.3 降级：解析条目少于 5，整期一条，附原文链接。"""
    return (source_band(compact) + '<div style="margin-top: 16px; border-top: 1px solid ' + INK + ';"><div style="display: flex; flex-direction: column; gap: 12px; padding: 28px 0 24px 0; border-bottom: 1px solid ' + RULE + ';">'
            + kai('本期解析失败，已保留原文链接', 20) + '<a href="#" style="display: inline-flex; align-items: center; gap: 6px;">' + kai('科技爱好者周刊（第 366 期）：' + WEEKLY['topic'], 15) + icon('arrow-up-right', 13, INK) + '</a></div></div>')

def anchors(compact=False):
    items = ''.join('<a href="#" class="t" style="font-family: ' + KAIF + '; font-size: 15px; white-space: nowrap;">' + s + '</a>' for s in SECTIONS)
    return '<div style="display: flex; gap: ' + ('16px' if compact else '24px') + '; padding: 16px 0; border-bottom: 1px solid ' + INK + '; overflow: hidden;">' + items + '</div>'

def weekly_sections(compact=False):
    out = []
    for s in ['本周话题', '科技动态', '文章', '工具']:
        head = '<div style="padding: ' + ('28px 0 4px 0' if compact else '32px 0 8px 0') + ';">' + kai(s, 22) + '</div>' + hrule()
        rows = ''.join(item(i + 1, t, sm, compact) for i, (t, sm, _tag, _why) in enumerate(WEEKLY_ITEMS[s]))
        out.append('<section>' + head + rows + '</section>')
    return ''.join(out)

def weekly():
    inner = (masthead('周刊') + '<div style="padding: 0 40px 28px 40px;">' + page_head(WEEKLY['week'], WEEKLY['year'], WEEKLY['range'], controls('第 35 周', '第 37 周'))
             + source_band() + anchors() + weekly_sections() + foot_link(WEEKLY['src'] + ' 原文') + rss_section()
             + footer_site('下周 · 第 37 周 · 9月7日起', '最新日刊 · 9月8日', controls('第 35 周', '第 37 周')) + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 2500)

def weekly_states():
    inner = (masthead('周刊') + '<div style="padding: 0 40px 28px 40px;">' + page_head(WEEKLY['week'], WEEKLY['year'], WEEKLY['range'], controls('第 35 周', '第 37 周'))
             + degraded_section() + rss_section() + footer_site('下周 · 第 37 周 · 9月7日起', '最新日刊 · 9月8日') + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1300)

def weekly_mobile():
    ctl = '<div style="display: flex; gap: 8px; padding: 14px 0 0 0;">' + ctrl('第 35 周', il='chevron-left', h=44) + ctrl('归档', h=44) + ctrl('第 37 周', ir='chevron-right', off=True, h=44) + '</div>'
    inner = (masthead(compact=True) + '<div style="padding: 0 24px 32px 24px;">' + page_head(WEEKLY['week'], WEEKLY['year'], WEEKLY['range'], '', compact=True) + ctl
             + source_band(True) + anchors(True) + weekly_sections(True) + '<div style="padding-top: 8px;">' + foot_link(WEEKLY['src'] + ' 原文') + '</div>' + rss_section(True)
             + '<div style="border-top: 2px solid ' + INK + '; margin-top: 40px; padding-top: 24px; display: flex; flex-direction: column; gap: 12px;">' + mono2('下周 · 第 37 周 · 9月7日起') + link('最新日刊 · 9月8日') + link('周刊归档') + '</div></div>')
    return doc(sheet(inner, width=390, margin='0'), FONTS, PAPER, INK, SERIF, css(), 2900)

# ---------- 归档 ----------

def archive_daily():
    rows = ''.join('<div style="display: grid; grid-template-columns: 24px 150px 110px minmax(0, 1fr) auto; gap: 0 16px; align-items: center; padding: 16px 0; border-bottom: 1px solid ' + RULE + ';">'
                   '<span style="display: flex; align-items: center;">' + mark(k) + '</span>' + link(d, 20) + kai(w, 15, INK2) + mixed(st, INK if k == 'ok' else INK2, 13) + '<span>' + (mixed(src, INK2, 13) if src else '') + '</span></div>'
                   for d, w, k, st, src in DAYS)
    month = '<div style="display: flex; align-items: center; justify-content: space-between; padding: 32px 0 8px 0;">' + kai('9 月', 22) + mono2('8 期 · 1 空刊 · 1 缺期') + '</div>' + hrule() + rows
    aug = '<div style="display: flex; align-items: center; justify-content: space-between; padding: 32px 0 8px 0;">' + '<a href="#" style="display: inline-flex; align-items: center; gap: 8px;">' + kai('8 月', 22) + icon('chevron-down', 16, INK) + '</a>' + mono2('31 期') + '</div>' + hrule()
    inner = (masthead('日刊') + '<div style="padding: 0 40px 28px 40px;">' + page_head('日刊归档', '2026', '最新 9月8日', controls('8 月', '10 月', mid='9 月'))
             + month + aug + footer_site('明早 06:00 · 下一期', '最新日刊 · 9月8日') + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1500)

def archive_weekly():
    rows = ''.join('<div style="display: grid; grid-template-columns: 24px 130px 190px minmax(0, 1fr) auto; gap: 0 16px; align-items: center; padding: 16px 0; border-bottom: 1px solid ' + RULE + ';">'
                   '<span style="display: flex; align-items: center;">' + mark(k) + '</span>' + link(w, 20) + kai(r, 15, INK2) + (kai(src, 15) if k == 'ok' else kai(src, 15, INK2)) + '<span>' + (mono2(n) if n else '') + '</span></div>'
                   for w, r, k, src, n in WEEKS)
    year = '<div style="display: flex; align-items: center; justify-content: space-between; padding: 32px 0 8px 0;">' + kai('2026 年', 22) + mono2('36 周 · 1 周无内容') + '</div>' + hrule() + rows
    y25 = '<div style="display: flex; align-items: center; justify-content: space-between; padding: 32px 0 8px 0;">' + '<a href="#" style="display: inline-flex; align-items: center; gap: 8px;">' + kai('2025 年', 22) + icon('chevron-down', 16, INK) + '</a>' + mono2('52 周') + '</div>' + hrule()
    inner = (masthead('周刊') + '<div style="padding: 0 40px 28px 40px;">' + page_head('周刊归档', '2026', '最新 第 36 周', controls('2025', '2027', mid='2026'))
             + year + y25 + footer_site('下周 · 第 37 周 · 9月7日起', '最新周刊 · 第 36 周') + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1400)

# ---------- 搜索 ----------

def hit(text, size, color):
    """命中词：墨色 2px 下划线，不用颜色块。"""
    for h in SEARCH_HITS:
        text = text.replace(h, '<span style="color: ' + INK + '; text-decoration: underline; text-decoration-thickness: 2px; text-underline-offset: 4px;">' + h + '</span>')
    return kai(text, size, color, ' line-height: 1.7;')

def search_head(query, placeholder=False):
    q = kai(query, 32, INK2 if placeholder else INK, ' line-height: 1;') if placeholder else kai(query, 32, INK, ' line-height: 1;')
    if placeholder:
        q = kai(query, 20, INK2, ' line-height: 1;')
    return ('<div style="display: flex; align-items: center; justify-content: space-between; gap: 24px; padding: 32px 0 20px 0; border-bottom: 2px solid ' + INK + ';">'
            '<div style="display: flex; align-items: center; gap: 16px; min-width: 0;">' + icon('search', 24, INK) + q + '</div>' + btn('搜索', primary=True) + '</div>')

def filters(active_type='全部', active_date='全部', on_sources=()):
    group = lambda l, c: '<div style="display: flex; flex-direction: column; gap: 8px;">' + kai(l, 12, INK2) + c + '</div>'
    srcs = '<span style="display: inline-flex; gap: 8px; align-items: center; height: 40px;">' + ''.join(chip_outline(s, s in on_sources) for s in ['Hacker News', 'GitHub Trending', 'Hackaday', '阮一峰周刊']) + '</span>'
    custom = ''
    if active_date == '自定义':
        box = lambda v: '<span style="display: inline-flex; align-items: center; height: 40px; padding: 0 12px; border: 1px solid ' + INK + '; margin-left: -1px;">' + mono2(v, INK, 13) + '</span>'
        custom = '<span style="display: inline-flex; align-items: center;">' + box('2026-08-01') + '<span style="padding: 0 8px;">' + kai('至', 13, INK2) + '</span>' + box('2026-09-08') + '</span>'
    return ('<div style="display: flex; gap: 40px; align-items: flex-start; padding: 20px 0; border-bottom: 1px solid ' + INK + '; flex-wrap: wrap;">'
            + group('刊物', seg(['全部', '日刊', '周刊'], active_type)) + group('来源', srcs) + group('日期', '<span style="display: inline-flex; gap: 16px; align-items: center;">' + seg(['近 7 天', '近 30 天', '全部', '自定义'], active_date) + custom + '</span>') + '</div>')

def search_row(pub, src, where, title, snippet, date):
    eyebrow = '<div style="display: flex; align-items: center; gap: 12px;">' + chip(pub) + txt(src, 13, INK2, 500) + mono2('·') + kai(where, 13, INK2) + mono2('·') + kai(date, 13, INK2) + '</div>'
    t = '<a href="#" style="display: block; margin-top: 10px;">' + hit(title, 20, INK) + '</a>'
    s = '<div style="margin-top: 6px; max-width: 820px;">' + hit(snippet, 15, INK2) + '</div>'
    links = '<div style="display: flex; gap: 20px; margin-top: 10px;">' + link('所在期 · ' + where, 13) + '<a href="#" style="display: inline-flex; align-items: center; gap: 4px;">' + kai('原文', 13) + icon('arrow-up-right', 12, INK) + '</a></div>'
    return '<div style="padding: 20px 0; border-bottom: 1px solid ' + RULE + ';">' + eyebrow + t + s + links + '</div>'

def pager(cur, total):
    return ('<div style="display: flex; align-items: center; justify-content: space-between; padding-top: 20px;">' + ctrl('上一页', il='chevron-left', off=True) + mono2(str(cur) + ' / ' + str(total), INK, 13) + ctrl('下一页', ir='chevron-right', off=(cur == total)) + '</div>')

def search():
    rows = ''.join(search_row(*r) for r in SEARCH_RESULTS)
    count = '<div style="padding: 16px 0 4px 0;">' + mixed(str(len(SEARCH_RESULTS)) + ' 条结果', INK2, 13) + '</div>'
    inner = (masthead('搜索') + '<div style="padding: 0 40px 28px 40px;">' + search_head(SEARCH_Q) + filters(active_date='自定义') + count + rows + pager(1, 1)
             + footer_site('明早 06:00 · 下一期', '最新日刊 · 9月8日') + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1500)

def search_states():
    initial = (masthead('搜索') + '<div style="padding: 0 40px 40px 40px;">' + search_head('搜标题、摘要或来源。拼写不准也可以。', placeholder=True) + filters()
               + '<div style="padding-top: 24px;">' + link('最新日刊 · 9月8日') + '</div></div>')
    q = '量子 咖啡机'
    empty = (masthead('搜索') + '<div style="padding: 0 40px 40px 40px;">' + search_head(q) + filters('周刊', '近 30 天', ('阮一峰周刊',))
             + '<div style="display: flex; flex-direction: column; gap: 16px; padding: 32px 0 8px 0;">' + kai('没有找到「' + q + '」相关内容。试试更短的关键词，或放宽筛选。', 20, INK, ' line-height: 1.6;') + '<div>' + btn('清除筛选', il='x') + '</div></div></div>')
    limited = (masthead('搜索') + '<div style="padding: 0 40px 40px 40px;">' + search_head(SEARCH_Q) + filters()
               + '<div style="padding: 32px 0 8px 0;">' + kai('操作过于频繁，请稍后再试。', 20) + '</div></div>')
    down = (masthead('搜索') + '<div style="padding: 0 40px 40px 40px;">' + search_head(SEARCH_Q) + filters()
            + '<div style="padding: 32px 0 8px 0;">' + kai('搜索暂不可用，请稍后重试。', 20) + '</div></div>')
    return doc(sheet(initial, h=0, margin='32px auto 0 auto') + sheet(empty, h=0, margin='48px auto 0 auto') + sheet(limited, h=0, margin='48px auto 0 auto') + sheet(down, h=0, margin='48px auto 48px auto'), FONTS, GROUND, INK, SERIF, css(), 2900)

# ---------- 登录 ----------

def login_card(message=None):
    band = '<div style="height: 80px; background: ' + INK + '; display: flex; align-items: center; justify-content: center;"><span style="font-family: ' + NAME + '; font-size: 40px; font-weight: 900; letter-spacing: 0.02em; text-transform: uppercase; color: ' + PAPER + '; line-height: 1;">lowpass</span></div>'
    art = ('<div style="border: 1px solid ' + INK + '; padding: 20px; margin-top: 32px;"><svg viewBox="0 0 260 138" width="100%" fill="none" stroke="' + INK + '" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" style="display: block;">' + ill_sunrise() + '</svg></div>')
    tagline = '<div style="padding: 28px 0 24px 0; text-align: center;">' + kai('滤掉噪音，留下信号。', 20) + '</div>'
    b = lambda l: '<a href="#" style="display: flex; align-items: center; justify-content: center; height: 44px; border: 1px solid ' + INK + ';">' + kai(l, 15) + '</a>'
    buttons = '<div style="display: flex; flex-direction: column; gap: 8px;">' + b('使用 Google 登录') + b('使用 GitHub 登录') + '</div>'
    msg = ('<div style="margin-top: 20px; display: flex; gap: 8px; align-items: flex-start;">' + icon('triangle-alert', 14, INK2) + kai(message, 13, INK2, ' line-height: 1.6;') + '</div>') if message else ''
    return sheet(band + '<div style="padding: 0 32px 36px 32px;">' + art + tagline + buttons + msg + '</div>', width=400, h=0, margin='0')

def login():
    cards = ('<div style="display: flex; gap: 40px; justify-content: center; align-items: flex-start; flex-wrap: wrap; padding: 60px 40px; max-width: 1360px; margin: 0 auto;">'
             + login_card() + login_card('已取消登录。') + login_card('登录失败，请重试。') + login_card('这个邮箱无法自动合并。如果你之前用其他方式登录过，请改用原方式。') + '</div>')
    return doc(cards, FONTS, GROUND, INK, SERIF, css(), 1500)

# ---------- 设置 ----------

def settings():
    row = lambda k, v: '<div style="display: grid; grid-template-columns: 160px minmax(0, 1fr); gap: 0 24px; align-items: center; padding: 18px 0; border-bottom: 1px solid ' + RULE + ';">' + kai(k, 13, INK2) + '<div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">' + v + '</div></div>'
    avatar = '<span style="width: 48px; height: 48px; border-radius: 50%; border: 1px solid ' + INK + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 20, INK) + '</span>'
    body = (row('头像与显示名', avatar + txt('Drew Lee', 20, INK, 500)) + row('邮箱', mono2('drew@example.com', INK, 13))
            + row('角色', chip('管理员') + kai('邮箱在白名单中', 13, INK2)) + row('Google', txt('已绑定', 15) + mixed('· 2026-09-08 14:02 · 主邮箱', INK2, 13))
            + row('GitHub', kai('未绑定', 15, INK2) + link('使用 GitHub 登录以绑定', 15)) + row('本次会话', mixed('2026-09-09 08:12 登录 · 30 天内免登录 · 2026-12-08 到期', INK2, 13)))
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('设置', 'drew@example.com', 'Drew Lee', btn('登出', il='log-out')) + '<div style="padding-top: 8px;">' + body + '</div>'
             + footer_site('明早 06:00 · 下一期', '最新日刊 · 9月8日') + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1000)

# ---------- 管理后台 ----------

def admin_nav(active):
    items = []
    for i, n in enumerate(['信息源', '期', '用户', '设置']):
        on = n == active
        st = ('flex: 1 1 0; display: flex; align-items: center; justify-content: center; height: 56px; border: 1px solid ' + INK + ';' + (' background: ' + INK + ';' if on else '') + (' margin-left: -1px;' if i else ''))
        items.append('<a href="#" style="' + st + '">' + kai(n, 20, PAPER if on else INK) + '</a>')
    return '<div style="display: flex; margin-top: 24px;">' + ''.join(items) + '</div>'

def health(kind, text):
    return mark('ok' if kind == 'ok' else 'empty') + kai(text, 15, INK if kind == 'ok' else INK2)

def admin_sources():
    rows = [[mono2(o, INK, 13), txt(n, 15, INK, 500), txt(a, 15), chip_outline(p), kai(st, 15), health(hk, ht), mixed(last, INK2, 13), mixed(nxt, INK2, 13),
             link('编辑', 13) + link('测试抓取', 13) + link('停用', 13)] for o, n, a, p, st, hk, ht, last, nxt in SOURCES_ADMIN]
    t = table(['排序', '名称', '适配器', '刊物', '状态', '健康度', '上次抓取', '下次计划', '操作'], rows, ['40px', '170px', '120px', '60px', '44px', '100px', 'minmax(0, 1fr)', '120px', '150px'])
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('管理后台', 'admin', '信息源', btn('新建来源', primary=True, il='plus')) + admin_nav('信息源')
             + '<div style="padding-top: 28px;">' + t + '</div>' + '<div style="padding-top: 16px;">' + mixed('4 个来源 · 3 个日刊 · 1 个周刊', INK2, 13) + '</div>' + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 900)

def admin_source_form():
    form = ('<div style="display: flex; flex-direction: column; gap: 24px; padding-top: 28px; max-width: 760px;">'
            '<div style="display: flex; flex-direction: column; gap: 8px;">' + kai('适配器', 13, INK2) + seg(['Hacker News', 'GitHub Trending', 'RSS/Atom', '阮一峰周刊'], 'RSS/Atom') + '</div>'
            + field('feed 地址', 'https://hackaday.com/feed/', mono=True) + '<div style="display: flex; gap: 24px;">' + field('名称', 'Hackaday', note='默认取 feed 标题') + '<div style="display: flex; flex-direction: column; gap: 6px;">' + kai('刊物', 13, INK2) + seg(['日刊', '周刊'], '日刊') + '</div></div>'
            + '<div style="display: flex; gap: 24px;">' + field('条数上限', '10', mono=True, width='160px', note='1 到 50') + field('时间窗口（小时）', '24', mono=True, width='160px', note='1 到 72') + field('排序值', '3', mono=True, width='160px') + '</div>'
            + '<div style="display: flex; gap: 8px; padding-top: 8px;">' + btn('测试抓取', il='refresh-cw') + btn('保存', primary=True) + '</div></div>')
    preview_rows = ''.join('<div style="display: grid; grid-template-columns: 24px minmax(0, 1fr); gap: 12px; padding: 12px 0; border-bottom: 1px solid ' + RULE + ';">' + mono2(str(i + 1)) + '<div style="display: flex; flex-direction: column; gap: 4px;">' + txt(t, 15, INK, 500) + mono2(m) + '</div></div>'
                           for i, (t, m) in enumerate([('A Mechanical Keyboard Built From Scrap Relays', 'M. Okada · 09-08 03:10'), ('Reviving a 1980s Oscilloscope With an ESP32', 'R. Alvarez · 09-08 00:02'), ('Open-Source Weather Station Survives Its First Typhoon', 'S. Lindqvist · 09-07 21:40'), ('The Physics of a Perfect Pour-Over', 'M. Okada · 09-07 17:15'), ('The Telegraph Repeater, Revisited', 'R. Alvarez · 09-07 10:05')]))
    preview = ('<div style="margin-top: 40px;"><div style="display: flex; align-items: center; justify-content: space-between; padding-bottom: 10px; border-bottom: 1px solid ' + INK + ';">' + kai('测试抓取 · 前 5 条', 15) + mixed('用时 1.8 秒 · 解析 24 条 · 丢弃 0 条', INK2, 13) + '</div>' + preview_rows
               + '<div style="display: flex; gap: 8px; align-items: center; padding-top: 12px;">' + icon('triangle-alert', 14, INK2) + kai('1 条无发布时间，已用抓取时间代替。', 13, INK2) + '</div></div>')
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('新建来源', 'admin', 'RSS/Atom', ctrl('返回列表', il='chevron-left')) + admin_nav('信息源') + form + preview + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1500)

def admin_issues():
    def ops(k, pub):
        if k == 'missing':
            return btn('补生成', il='refresh-cw', h=32)
        return link('重抓某源', 13) + link('查看', 13)
    rows = [[chip_outline(p), mono2(key, INK, 13), '<span style="display: inline-flex; align-items: center; gap: 8px;">' + mark(k) + kai(st, 15, INK if k == 'ok' else INK2) + '</span>', mono2(t) if t else '', mixed(res, INK2, 13) if res else '', ops(k, p)] for p, key, st, t, res, k in ISSUES]
    t = table(['刊物', '周期键', '状态', '生成时间', '各源结果', '操作'], rows, ['70px', '120px', '160px', '120px', 'minmax(0, 1fr)', '150px'])
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('管理后台', 'admin', '期', btn('立即生成今日日刊', primary=True, il='refresh-cw')) + admin_nav('期')
             + '<div style="display: flex; align-items: center; justify-content: space-between; padding: 28px 0 16px 0;">' + seg(['全部', '日刊', '周刊'], '全部') + mixed('9 月 · 8 期 · 1 空刊 · 1 缺期', INK2, 13) + '</div>' + t + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1000)

def admin_users():
    rows = [[txt('Drew Lee', 15, INK, 500), mono2('drew@example.com', INK, 13), chip('管理员'), txt('Google · GitHub', 15, INK2), mono2('2026-09-09 08:12')],
            [txt('Mei Tanaka', 15, INK, 500), mono2('mei@example.org', INK, 13), chip_outline('成员'), txt('Google', 15, INK2), mono2('2026-09-08 22:40')],
            [txt('Jonas Berg', 15, INK, 500), mono2('jonas@example.net', INK, 13), chip_outline('成员'), txt('GitHub', 15, INK2), mono2('2026-09-06 09:15')]]
    t = table(['显示名', '邮箱', '角色', '登录方式', '最近登录'], rows, ['200px', '240px', '90px', 'minmax(0, 1fr)', '170px'])
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('管理后台', 'admin', '用户', '') + admin_nav('用户') + '<div style="padding-top: 28px;">' + t + '</div>' + '<div style="padding-top: 16px;">' + mixed('3 个用户 · 只读', INK2, 13) + '</div></div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 800)

def admin_settings():
    sec = lambda title, body: '<div style="padding-top: 32px;"><div style="padding-bottom: 8px;">' + kai(title, 22) + '</div>' + hrule() + '<div style="padding-top: 20px;">' + body + '</div></div>'
    # 字段顶对齐；按钮与说明文字用上边距对齐到输入框那一行（标签 20px + 间距 6px = 26px）
    sched = ('<div style="display: flex; gap: 24px; align-items: flex-start;">' + field('日刊生成时间', '06:00', mono=True, width='160px', note='Asia/Shanghai，精确到分') + field('周刊检查时间', '09:00', mono=True, width='160px')
             + '<div style="padding-top: 26px;">' + btn('保存', primary=True) + '</div></div>')
    alerts = ('<div style="display: flex; flex-direction: column; gap: 14px;">'
              '<div style="display: flex; align-items: center; gap: 12px;">' + mark('ok') + kai('邮件', 15) + mono2('drew@example.com', INK2, 13) + kai('已配置', 13, INK2) + '</div>'
              '<div style="display: flex; align-items: center; gap: 12px;">' + mark('empty') + kai('IM webhook', 15) + kai('未配置', 13, INK2) + '</div>'
              '<div style="display: flex; align-items: center; gap: 12px; padding-top: 4px;">' + btn('发送测试告警') + mixed('上次测试 9月8日 14:20 · 成功', INK2, 13) + '</div></div>')
    allow = '<div style="display: flex; flex-direction: column; gap: 10px;">' + mono2('drew@example.com', INK, 13) + kai('白名单由环境配置，改动在下次登录生效。', 13, INK2) + '</div>'
    irows = ''.join('<div style="display: grid; grid-template-columns: 200px minmax(0, 1fr) 80px; gap: 0 16px; align-items: center; padding: 12px 0; border-bottom: 1px solid ' + RULE + ';">' + kai(n, 15) + txt(k, 15, INK2) + '<span style="display: flex; gap: 12px; justify-content: flex-end;">' + link('编辑', 13) + '</span></div>' for n, k in INTERESTS)
    interests = ('<div style="display: grid; grid-template-columns: 200px minmax(0, 1fr) 80px; gap: 0 16px; padding-bottom: 10px; border-bottom: 1px solid ' + INK + ';">' + kai('领域', 12, INK2) + kai('关键词', 12, INK2) + '<span></span></div>' + irows
                 + '<div style="display: flex; align-items: center; gap: 16px; padding-top: 16px;">' + btn('添加领域', il='plus') + mixed('改动只影响之后生成的期', INK2, 13) + '</div>')
    reasons = ('<div style="display: flex; gap: 24px; align-items: flex-start;">' + field('月费用上限', '50', mono=True, width='160px', note='超限停止生成并告警')
               + '<div style="padding-top: 26px; display: flex; align-items: center; gap: 24px; height: 66px; box-sizing: border-box;">' + mixed('今日调用 30 次 · 本月 ¥3.20 · 理由缺失 0 条', INK2, 13) + btn('重生成今日理由', il='refresh-cw') + '</div></div>')
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('管理后台', 'admin', '设置', '') + admin_nav('设置')
             + sec('调度', sched) + sec('告警', alerts) + sec('管理员白名单（只读）', allow) + sec('兴趣画像', interests) + sec('推荐理由', reasons) + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1900)

# ---------- 后台补稿：抓取记录、对话框与提示、其他适配器表单 ----------

RUNS = [('9月8日 06:12:01', '1.8 秒', 'ok', '成功', '1', '10', '0', '', '调度'),
        ('9月7日 07:07:30', '60.0 秒', 'fail', '失败', '3', '', '', '连接超时', '调度'),
        ('9月7日 07:05:30', '60.0 秒', 'fail', '失败', '2', '', '', '连接超时', '调度'),
        ('9月7日 07:05:00', '60.0 秒', 'fail', '失败', '1', '', '', '连接超时', '调度'),
        ('9月6日 06:11:02', '2.1 秒', 'ok', '成功', '1', '10', '0', '', '调度'),
        ('9月5日 06:04:31', '60.0 秒', 'fail', '失败', '3', '', '', '连接超时', '调度'),
        ('9月5日 06:02:30', '60.0 秒', 'fail', '失败', '2', '', '', '连接超时', '调度'),
        ('9月5日 06:00:00', '60.0 秒', 'fail', '失败', '1', '', '', '连接超时', '调度'),
        ('9月4日 06:42:10', '1.9 秒', 'ok', '成功', '1', '10', '0', '', '手动'),
        ('9月4日 06:12:00', '2.0 秒', 'ok', '成功', '1', '10', '0', '', '调度'),
        ('9月2日 06:12:03', '2.4 秒', 'ok', '成功', '1', '8', '2', '2 条缺链接，已丢弃', '调度'),
        ('9月1日 15:20:11', '1.7 秒', 'ok', '成功', '1', '5', '0', '预览前 5 条', '测试')]

def admin_runs():
    rows = [[mono2(t, INK, 13), mono2(d), '<span style="display: inline-flex; align-items: center; gap: 8px;">' + mark('ok' if k == 'ok' else 'empty') + kai(st, 15, INK if k == 'ok' else INK2) + '</span>',
             mono2(a + ' / 3'), mono2(n) if n else '', mono2(dr) if dr else '', kai(err, 13, INK2) if err else '', kai(trg, 13, INK2)] for t, d, k, st, a, n, dr, err, trg in RUNS]
    t = table(['开始时间', '耗时', '状态', '尝试', '条目', '丢弃', '错误摘要', '触发'], rows, ['150px', '80px', '110px', '70px', '60px', '60px', 'minmax(0, 1fr)', '60px'])
    right = '<div style="display: flex; gap: 8px;">' + ctrl('返回列表', il='chevron-left') + btn('重抓 9月8日', primary=True, il='refresh-cw') + '</div>'
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('Hackaday', 'RSS/Atom', '抓取记录', right) + admin_nav('信息源')
             + '<div style="display: flex; align-items: center; justify-content: space-between; padding: 28px 0 16px 0;">' + seg(['全部', '成功', '失败'], '全部') + mixed('最近 50 次 · 保留 30 天 · 12 条', INK2, 13) + '</div>' + t + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1300)

def dialog(text, cancel, confirm):
    return ('<div style="position: absolute; inset: 0; background: rgba(29, 29, 27, 0.4); display: flex; align-items: center; justify-content: center;">'
            '<div style="width: 480px; background: ' + PAPER + '; border: 1px solid ' + INK + '; border-top: 2px solid ' + INK + '; padding: 28px 28px 24px 28px; display: flex; flex-direction: column; gap: 24px;">'
            + kai(text, 20, INK, ' line-height: 1.6;') + '<div style="display: flex; justify-content: flex-end; gap: 8px;">' + ctrl(cancel) + btn(confirm, primary=True) + '</div></div></div>')

def toast(text, kind='info'):
    ic = {'info': 'clock', 'ok': 'check', 'fail': 'triangle-alert'}[kind]
    return ('<div style="display: inline-flex; align-items: center; gap: 12px; height: 44px; padding: 0 16px; background: ' + PAPER + '; border: 1px solid ' + INK + ';">'
            + icon(ic, 16, INK) + kai(text, 15) + '<span style="padding-left: 8px;">' + icon('x', 14, INK2) + '</span></div>')

def admin_dialogs():
    issues_bg = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('管理后台', 'admin', '期', btn('立即生成今日日刊', primary=True, il='refresh-cw')) + admin_nav('期')
                 + '<div style="padding-top: 28px;">' + table(['刊物', '周期键', '状态', '生成时间', '各源结果', '操作'], [[chip_outline(p), mono2(key, INK, 13), kai(st, 15), mono2(t) if t else '', mixed(res, INK2, 13) if res else '', link('查看', 13)] for p, key, st, t, res, k in ISSUES[:3]], ['70px', '120px', '160px', '120px', 'minmax(0, 1fr)', '150px']) + '</div></div>')
    sources_bg = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('管理后台', 'admin', '信息源', btn('新建来源', primary=True, il='plus')) + admin_nav('信息源')
                  + '<div style="padding-top: 28px;">' + table(['排序', '名称', '适配器', '刊物', '状态'], [[mono2(o, INK, 13), txt(n, 15, INK, 500), txt(a, 15), chip_outline(p), kai(st, 15)] for o, n, a, p, st, hk, ht, last, nxt in SOURCES_ADMIN[:3]], ['40px', '200px', '160px', '80px', 'minmax(0, 1fr)']) + '</div></div>')
    s1 = '<div style="position: relative;">' + issues_bg + dialog('今日日刊已存在。要对所有来源重抓吗？', '取消', '重抓全部') + '</div>'
    s2 = '<div style="position: relative;">' + sources_bg + dialog('停用后不再抓取，历史内容保留。确认停用 Hackaday？', '取消', '停用') + '</div>'
    toasts = (masthead('') + '<div style="padding: 32px 40px 40px 40px; display: flex; flex-direction: column; gap: 16px;">' + kai('操作反馈：页面顶部一行，4 秒后自动收起，失败的不自动收起', 13, INK2)
              + '<div style="display: flex; gap: 16px; flex-wrap: wrap;">' + toast('正在重抓 Hackaday…') + toast('已更新 Hackaday（10 条）', 'ok') + toast('重抓失败：连接超时。已保留原内容。', 'fail') + toast('已发送测试告警', 'ok') + '</div></div>')
    return doc(sheet(s1, h=0, margin='32px auto 0 auto') + sheet(s2, h=0, margin='48px auto 0 auto') + sheet(toasts, h=0, margin='48px auto 48px auto'), FONTS, GROUND, INK, SERIF, css(), 1900)

def adapter_form(title, fields_html):
    return ('<div style="padding-top: 32px;"><div style="padding-bottom: 8px;">' + kai(title, 22) + '</div>' + hrule() + '<div style="display: flex; flex-direction: column; gap: 24px; padding-top: 20px; max-width: 760px;">' + fields_html + '</div></div>')

def admin_source_forms():
    hn = adapter_form('Hacker News', '<div style="display: flex; flex-direction: column; gap: 8px;">' + kai('榜单', 13, INK2) + seg(['top', 'best'], 'top') + '</div>'
                      + '<div style="display: flex; gap: 24px;">' + field('条数', '10', mono=True, width='160px', note='1 到 100') + field('最低分数', '0', mono=True, width='160px') + field('排序值', '1', mono=True, width='160px') + '</div>')
    gh = adapter_form('GitHub Trending', field('语言列表', 'Rust, TypeScript, Python', note='最多 3 个，留空为综合榜')
                      + '<div style="display: flex; gap: 24px;">' + field('每语言条数', '5', mono=True, width='160px', note='综合榜 10，多语言各 5') + field('排序值', '2', mono=True, width='160px') + '</div>')
    ry = adapter_form('阮一峰周刊', '<div style="display: flex; gap: 24px;">' + field('仓库', 'ruanyf/weekly', mono=True, width='320px', note='固定，不可改') + field('最少条目阈值', '5', mono=True, width='160px', note='低于此值降级为整期一条并告警') + '</div>')
    fails = ('<div style="padding-top: 32px;"><div style="padding-bottom: 8px;">' + kai('测试抓取失败时', 22) + '</div>' + hrule() + '<div style="display: flex; flex-direction: column; gap: 14px; padding-top: 20px;">'
             + '<div style="display: flex; align-items: center; gap: 10px;">' + icon('triangle-alert', 14, INK2) + kai('不是有效的 RSS/Atom，请检查地址。', 15) + '</div>'
             + '<div style="display: flex; align-items: center; gap: 10px;">' + icon('triangle-alert', 14, INK2) + kai('连接超时（30 秒），请检查地址或稍后重试。', 15) + '</div>'
             + '<div style="display: flex; align-items: center; gap: 8px; padding-top: 8px;">' + btn('测试抓取', il='refresh-cw') + btn('保存', primary=True) + '<span style="padding-left: 8px;">' + kai('尚未通过测试，仍可保存。', 13, INK2) + '</span></div></div></div>')
    inner = (masthead('') + '<div style="padding: 0 40px 28px 40px;">' + page_head('新建来源', 'admin', '其他适配器', ctrl('返回列表', il='chevron-left')) + admin_nav('信息源') + hn + gh + ry + fails + '</div>')
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1900)

