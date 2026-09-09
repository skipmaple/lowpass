"""第九轮：单栏、十条一致、tab 切换来源、每条带推荐理由与兴趣标签。"""
from common import *
from pages_warm import doc
from pages_press import HN30, GH25, HAD12, ill_bubbles, ill_branches, ill_solder, ill_sunrise
from pages_front2 import (GROUND, PAPER, INK, INK2, GREEN, RULE, NAME, SERIF, MONOF, FONTS, css, mixed, mono2, label, mm,
                          hn_meta, gh_meta, had_meta, ctrl, masthead, issue_head, footer, sheet, foot_link)

PAPER_DIM = 'rgba(232, 227, 218, 0.72)'

# 兴趣标签与推荐理由（示例数据，按兴趣画像写：嵌入式、AI/LLM、前端、后端、后端架构、UI/UX、硬件、电子机械、开发者效率、智能家居）
REASON_HN = [
    ('开发者效率', '命中开发工具偏好：Rust 写的终端日志查看器，大文件过滤与高亮的做法可直接用在日常排障。'),
    ('后端架构', '后端架构相关：PostgreSQL 全文检索在生产中的索引与排序取舍，对应用内建搜索代替搜索引擎的选择。'),
    ('后端开发', '后端开发流程：反方视角看 feature flag 造成的分支复杂度，适合对照自己的发布方式。'),
    ('开发者效率', '开发者效率话题：讨论如何筛选技术资讯而不过载，与每日摘要要解决的问题相同。'),
    ('后端架构', '后端架构：把 SQLite 当作单文件格式的设计取舍，对嵌入式与桌面工具的数据存储都有启发。'),
    ('智能家居', '命中智能家居与硬件兴趣：拆解廉价温控器的通信协议，接入 Home Assistant 的思路可复用。'),
    ('后端架构', '后端架构与 Rust：用 Rust 写 Kubernetes Operator 的实战记录，覆盖调谐循环与错误处理。'),
    ('后端开发', '后端底层：io_uring 的入门讲解，理解 Linux 异步 IO 对服务端性能优化有直接帮助。'),
    ('后端架构', '自托管运维：十年邮件服务器的踩坑总结，对自己维护一台小服务器的人参考价值高。'),
    ('后端架构', '数据库内核基础：B 树分裂的可视化讲解，补上索引原理这一块。'),
]
REASON_GH = [
    ('嵌入式', '嵌入式与后端架构交集：占用极小的时序数据库，适合传感器数据在设备端落盘。'),
    ('开发者效率', '与自托管 RSS 阅读器直接相关：TypeScript 实现并带全文检索，可对照本项目的搜索设计。'),
    ('开发者效率', '开发工具：面向终端的结构化日志查看器，和今天 Hacker News 第 1 条互为参照。'),
    ('AI / LLM', '本地模型部署：面向笔记本 GPU 的量化工具链，降低本地跑 LLM 的显存门槛。'),
    ('后端开发', 'Ruby 与部署：单机部署的配方与清单，与用 Kamal 管一台 VPS 的场景高度贴合。'),
    ('前端开发', '前端与 UI：Tailwind v4 的可复制 UI 区块，适合快速搭出管理后台页面。'),
    ('后端架构', '后端架构：只依赖单个数据库的任务队列，与不引入 Redis 的抓取调度思路一致。'),
    ('前端开发', '前端交互：浏览器白板的基础图元库，可用于原型工具或设计系统实验。'),
    ('开发者效率', '开发者效率：带上下文记忆的 shell，命令补全与历史检索的新尝试。'),
    ('智能家居', '嵌入式与 IoT：单头文件 MQTT 客户端，ESP32 接 Home Assistant 的轻量选择。'),
]
REASON_HAD = [
    ('硬件设计', '硬件与电子机械：用继电器做键盘，从驱动电路到消抖都有细节，可读性高。'),
    ('嵌入式', '嵌入式命中：ESP32 替换老示波器的触发板，涉及 ADC 采样与固件设计。'),
    ('智能家居', 'IoT 与硬件：开源气象站的 LoRa 通信与 3D 打印外壳，实地可靠性经验难得。'),
    ('硬件设计', '传感器应用：用称重传感器与流量测量分析手冲咖啡，与硬件兴趣相关度中等。'),
    ('电子机械', '电子机械史：十九世纪继电器中继的原理复刻，理解继电器逻辑的好材料。'),
    ('硬件设计', '硬件与音频：三台口袋收音机的电路拆解，外加一次天线理论复习。'),
    ('电子机械', '电机控制与自动化：两台步进电机加旧打印机机构改成绘图仪，固件一个周末成型。'),
    ('硬件设计', '硬件测量：电视棒加屏蔽盒做频谱分析仪，射频入门的低成本方案。'),
    ('硬件设计', '电路设计：自行车发电机的稳压与充电管理，讨论为何调节比磁体更关键。'),
    ('电子机械', '机器人与自动化：自制旋转激光测距扫描地下室，点云处理用现成零件完成。'),
]

SOURCES = [
    ('hn', 'Hacker News', '前 10 条 · 榜单顺序', ill_bubbles),
    ('gh', 'GitHub Trending', '今日前 10 · 新增 star 降序', ill_branches),
    ('had', 'Hackaday', '近 24 小时最新 10 篇', ill_solder),
]
NAMES = {k: n for k, n, _, _ in SOURCES}

def isvg(inner, size, color):
    return ('<svg viewBox="0 0 120 78" width="' + str(round(size * 120 / 78)) + '" height="' + str(size) + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex: none; display: block;">' + inner + '</svg>')

def tabs(active, kickers=None, compact=False):
    """来源切换：三个并排的纸报式索引条。当前项反白成墨色块，与报头黑带呼应；其余描边。"""
    kickers = kickers or {}
    items = []
    for i, (key, name, kick, ill) in enumerate(SOURCES):
        on = key == active
        join = ' margin-left: -1px;' if i else ''
        if compact:
            st = ('flex: 1 1 0; display: inline-flex; align-items: center; justify-content: center; height: 44px; padding: 0 6px; border: 1px solid ' + INK + '; font-family: ' + SERIF + '; font-size: 14px; font-weight: 500; white-space: nowrap;'
                  + (' background: ' + INK + '; color: ' + PAPER + ';' if on else ' color: ' + INK + ';') + join)
            items.append('<a href="#" style="' + st + '">' + name + '</a>')
            continue
        fg = PAPER if on else INK
        fg2 = PAPER_DIM if on else INK2
        inner = ill().replace(PAPER, INK) if on else ill()
        st = ('flex: 1 1 0; display: flex; align-items: center; gap: 14px; padding: 14px 24px 14px 18px; border: 1px solid ' + INK + '; min-width: 0;'
              + (' background: ' + INK + ';' if on else '') + join)
        items.append('<a href="#" style="' + st + '">' + isvg(inner, 40, fg)
                     + '<div style="display: flex; flex-direction: column; gap: 5px;"><span style="font-family: ' + NAME + '; font-size: 24px; font-weight: 700; line-height: 1; color: ' + fg + ';">' + name + '</span>'
                     + '<span style="white-space: nowrap;">' + mixed(kickers.get(key, kick), fg2, 12) + '</span></div></a>')
    return '<div style="display: flex; padding: ' + ('16px 0 0 0' if compact else '24px 0 0 0') + ';">' + ''.join(items) + '</div>'

def chip(text):
    return ('<span style="display: inline-flex; align-items: center; height: 24px; padding: 0 8px; border: 1px solid ' + RULE + '; white-space: nowrap;">' + mixed(text, INK2, 12) + '</span>')

def item(rank, title, meta_html, tag, reason, secondary=None, compact=False):
    """十条一致的条目：序号、标题、说明、元数据、兴趣标签、推荐理由（绿色细竖线）。"""
    reason_html = ('<div style="border-left: 2px solid ' + GREEN + '; padding: 1px 0 1px 12px; margin-top: 4px; max-width: 820px; font-size: ' + ('14.5px' if compact else '15px') + '; line-height: 1.55; color: ' + INK2 + ';">' + reason + '</div>')
    sec = ('<span style="font-size: ' + ('14.5px' if compact else '15px') + '; line-height: 1.5; color: ' + INK2 + ';">' + secondary + '</span>') if secondary else ''
    title_html = '<a href="#" class="t" style="font-size: ' + ('18px' if compact else '20px') + '; line-height: 1.35; font-weight: 500;">' + title + '</a>'
    if compact:
        meta_line = '<span style="display: inline-flex; align-items: center; gap: 10px; flex-wrap: wrap;">' + meta_html + chip(tag) + '</span>'
        return ('<div style="display: grid; grid-template-columns: 28px minmax(0, 1fr); gap: 10px; padding: 16px 0; border-bottom: 1px solid ' + RULE + ';">'
                '<span style="padding-top: 4px; font-family: ' + MONOF + '; font-size: 13px; color: ' + INK2 + ';">' + rank.lstrip('0') + '</span>'
                '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0;">' + title_html + sec + meta_line + reason_html + '</div></div>')
    return ('<div style="display: grid; grid-template-columns: 40px minmax(0, 1fr) auto; gap: 16px; padding: 18px 0; border-bottom: 1px solid ' + RULE + ';">'
            '<span style="padding-top: 5px; font-family: ' + MONOF + '; font-size: 13px; color: ' + INK2 + ';">' + rank.lstrip('0') + '</span>'
            '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0;">' + title_html + sec + meta_html + reason_html + '</div>'
            '<div style="padding-top: 3px;">' + chip(tag) + '</div></div>')

def rows(active, compact=False):
    if active == 'hn':
        return ''.join(item(r, t, hn_meta(m), tag, why, None, compact) for (r, t, m), (tag, why) in zip(HN30[:10], REASON_HN))
    if active == 'gh':
        return ''.join(item(r, n, gh_meta(m, r), tag, why, d, compact) for (r, n, m, d), (tag, why) in zip(GH25[:10], REASON_GH))
    return ''.join(item(r, t, had_meta(m), tag, why, s, compact) for (r, t, m, s), (tag, why) in zip(HAD12[:10], REASON_HAD))

def failure_box(compact=False):
    text = ('<div style="display: flex; flex-direction: column; gap: 8px;"><span style="font-family: ' + SERIF + '; font-size: 20px; font-weight: 500;">今日抓取失败，已通知管理员</span>'
            + mm([('上次成功', 's'), ('9月7日 06:11', 'm'), ('·', 'm'), ('修复后本栏自动补齐', 's')]) + '</div>')
    art = ('<svg viewBox="0 0 260 138" width="130" height="69" fill="none" stroke="' + INK + '" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" style="display: block; opacity: 0.55;">' + ill_sunrise() + '</svg>')
    if compact:
        return '<div style="display: flex; flex-direction: column; gap: 16px; padding: 24px 0 20px 0; border-bottom: 1px solid ' + RULE + ';">' + art + text + '</div>'
    return ('<div style="display: grid; grid-template-columns: 130px minmax(0, 1fr); gap: 24px; align-items: center; padding: 28px 0 24px 0; border-bottom: 1px solid ' + RULE + ';">' + art + text + '</div>')

def body(active, compact=False, failed=False):
    inner = failure_box(compact) if failed else rows(active, compact)
    return ('<div style="border-top: 1px solid ' + INK + '; margin-top: ' + ('16px' if compact else '20px') + ';">' + inner + '</div>'
            + foot_link(NAMES[active] + ' 完整榜单'))

def page(active, compact=False, status=None, kickers=None, failed=False):
    controls = ('<div style="display: flex; gap: 8px; padding: 14px 0 0 0;">' + ctrl('9月7日', il='chevron-left', h=44) + ctrl('归档', h=44) + ctrl('9月9日', ir='chevron-right', off=True, h=44) + '</div>') if compact else ''
    return (masthead(compact=compact) + '<div style="padding: ' + ('0 20px 24px 20px' if compact else '0 40px 28px 40px') + ';">'
            + issue_head(status=status, compact=compact) + controls + tabs(active, kickers, compact) + body(active, compact, failed) + footer(compact) + '</div>')

def front3():
    return doc(sheet(page('hn')), FONTS, GROUND, INK, SERIF, css(), 2000)

def front3_gh():
    return doc(sheet(page('gh')), FONTS, GROUND, INK, SERIF, css(), 2300)

def front3_had():
    return doc(sheet(page('had')), FONTS, GROUND, INK, SERIF, css(), 2300)

def front3_states():
    k = {'hn': '抓取失败 · 上次成功 9月7日 06:11', 'gh': '今日无新内容'}
    return doc(sheet(page('hn', status='延迟生成于 07:05', kickers=k, failed=True)), FONTS, GROUND, INK, SERIF, css(), 900)

def front3_mobile():
    return doc(sheet(page('hn', compact=True), width=390, margin='0'), FONTS, PAPER, INK, SERIF, css(), 2350)
