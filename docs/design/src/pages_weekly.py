from common import *

SECTIONS = ['本周话题', '科技动态', '文章', '工具', '资源', '图片', '文摘', '言论']

WEEKLY_ITEMS = {
    '本周话题': [
        ('为什么值得给自己办一份日刊', '信息流没有边界，刊物有。每天一期、定稿不改，读完就能合上。', '中文 · 原文'),
    ],
    '科技动态': [
        ('25 美元的开源墨水屏时钟', '一块 4.2 寸墨水屏加一颗低功耗芯片，一次充电跑三个月，图纸与固件全部开放。', '英文 · 原文'),
        ('旧手机变家庭气象站', '把退役手机的传感器接进本地网络，配一块太阳能板放在窗外。', '英文 · 原文'),
        ('一个开源社区暂停接收自动生成的补丁', '维护者说审查成本已经超过收益，先关一年再看。', '英文 · 原文'),
    ],
    '文章': [
        ('PostgreSQL 全文搜索在生产环境的十个坑', '从分词到排序权重，作者把两年的踩坑记录整理成清单。', '英文 · 原文'),
        ('写给独立开发者的备份策略', '三份副本、两种介质、一份异地，以及怎样每季度真的演练一次恢复。', '中文 · 原文'),
        ('终端为什么仍是最好的界面', '可组合、可脚本、可搜索，四十年过去这三点没有被替代。', '英文 · 原文'),
    ],
    '工具': [
        ('termlog：终端里的结构化日志查看器', '按字段过滤、折叠与高亮，Rust 编写，单文件分发。', 'nine-tails/termlog'),
        ('lowlatency-db：嵌入式时序数据库', '面向单机与边缘设备，写入路径极短，占用极小。', 'acme/lowlatency-db'),
        ('atlas：Tailwind v4 的现成界面块', '复制即用的页面区块，无运行时依赖。', 'blocksmith/atlas'),
        ('recipes：单机部署清单与脚本', '一台机器跑完应用、数据库、备份与告警的全部配方。', 'singlebox/recipes'),
    ],
}

def witem(title, summary, meta):
    return ('<article style="display: flex; flex-direction: column; gap: 6px;">'
            '<a href="#" style="font-size: 16px; line-height: 1.5; color: #000000;">' + title + '</a>'
            '<span style="font-size: 15px; line-height: 1.5; color: ' + INK64 + ';">' + summary + '</span>'
            + mono(meta) + '</article>\n')

def section(name, items, top=40):
    return ('<section style="display: flex; flex-direction: column; gap: 20px; padding-top: ' + str(top) + 'px;">'
            '<h3 style="margin: 0; font-size: 16px; font-weight: 500; line-height: 1.4;">' + name + '</h3>'
            + ''.join(witem(*i) for i in items) + '</section>\n')

def source_head():
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<h2 style="margin: 0; font-size: 18px; font-weight: 500; line-height: 1.3;">阮一峰周刊</h2>'
            '<div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">'
            '<span style="font-size: 16px;">第 366 期：把信号从噪音里捞出来</span>'
            '<a href="#" style="display: inline-flex; align-items: center; gap: 4px; font-size: 14px; font-weight: 500; color: #000000;"><span>原文</span>' + icon('arrow-up-right', 16, INK) + '</a>'
            '</div>' + mono('9月5日 发布 · 52 条 · 8 个板块') + '</div>\n')

def weekly():
    controls = (button('第 35 周', 'outline', icon_left='chevron-left') + button('归档', 'outline')
                + button('第 37 周', 'outline', icon_right='chevron-right', disabled=True))
    header = issue_header('周刊 · 2026-W36', '第 36 周', '9月1日 至 9月7日', controls)
    anchors = ''.join(
        '<a href="#" style="font-size: 15px; color: ' + (INK if s == '本周话题' else INK64) + '; font-weight: ' + ('500' if s == '本周话题' else '400') + ';">' + s + '</a>'
        for s in SECTIONS
    )
    left = '<div style="display: flex; flex-direction: column; gap: 12px;">' + mono('板块', INK44) + anchors + '</div>\n'
    right = ('<div style="display: flex; flex-direction: column;">' + source_head()
             + section('本周话题', WEEKLY_ITEMS['本周话题'])
             + section('科技动态', WEEKLY_ITEMS['科技动态'])
             + section('文章', WEEKLY_ITEMS['文章'])
             + section('工具', WEEKLY_ITEMS['工具'])
             + '<div style="padding-top: 40px;">' + more_link('资源、图片、文摘、言论') + '</div>'
             + '</div>\n')
    content = ('<div style="display: grid; grid-template-columns: 200px minmax(0, 720px); gap: 64px; padding: 0 64px 80px 64px;">' + left + right + '</div>\n')
    return document(topbar('周刊') + header + content, 1440, 1500)

def weekly_mobile():
    header = (
        '<div style="display: flex; flex-direction: column; gap: 10px; padding: 20px 24px 8px 24px;">\n'
        '  ' + mono('周刊 · 2026-W36') + '\n'
        '  <h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: 34px; line-height: 1.1; display: flex; align-items: baseline; gap: 12px;">'
        '<span>第 36 周</span><span style="font-size: 15px; color: ' + INK64 + ';">9月1日 至 9月7日</span></h1>\n'
        '</div>\n'
        '<div style="display: flex; gap: 4px; padding: 8px 16px 16px 16px;">'
        + button('第 35 周', 'ghost', icon_left='chevron-left', height=36) + button('归档', 'ghost', height=36)
        + button('第 37 周', 'ghost', icon_right='chevron-right', height=36, disabled=True) + '</div>\n'
    )
    anchors = ''.join(
        '<span style="font-size: 14px; white-space: nowrap; color: ' + (INK if s == '本周话题' else INK64) + '; font-weight: ' + ('500' if s == '本周话题' else '400') + ';">' + s + '</span>'
        for s in SECTIONS[:6]
    )
    body = ('<div style="padding: 0 24px 40px 24px; display: flex; flex-direction: column; gap: 8px;">' + source_head()
            + '<div style="display: flex; gap: 20px; overflow: hidden; padding: 16px 0 4px 0; border-bottom: 1px solid ' + BORDER + ';">' + anchors + '</div>'
            + section('本周话题', WEEKLY_ITEMS['本周话题'], 24)
            + section('科技动态', WEEKLY_ITEMS['科技动态'], 32)
            + '</div>\n')
    return document(topbar_mobile() + header + body, 390, 1160)

def weekly_archive():
    controls = button('2025 年', 'outline', icon_left='chevron-left') + button('2027 年', 'outline', icon_right='chevron-right', disabled=True)
    header = issue_header('周刊归档', '2026 年', '', controls)
    weeks = [
        ('第 36 周', '09-01 至 09-07', '阮一峰周刊 · 第 366 期：把信号从噪音里捞出来', INK),
        ('第 35 周', '08-25 至 08-31', '阮一峰周刊 · 第 365 期：小而硬的工具', INK),
        ('第 34 周', '08-18 至 08-24', '阮一峰周刊 · 第 364 期：从零开始的备份', INK),
        ('第 33 周', '08-11 至 08-17', '本周无内容', INK44),
        ('第 32 周', '08-04 至 08-10', '阮一峰周刊 · 第 363 期：慢一点的网络', INK),
        ('第 31 周', '07-28 至 08-03', '阮一峰周刊 · 第 362 期：一台机器够用', INK),
    ]
    rows = ''
    for i, (w, rng, title, col) in enumerate(weeks):
        bg = ALT if i % 2 == 1 else 'transparent'
        rows += ('<a href="#" style="display: grid; grid-template-columns: 120px 160px minmax(0, 1fr) 20px; gap: 16px; align-items: center; padding: 14px 12px; border-radius: 8px; background: ' + bg + '; color: ' + col + ';">'
                 '<span style="font-size: 16px;">' + w + '</span>' + mono(rng) + '<span style="font-size: 16px;">' + title + '</span>' + icon('chevron-right', 18, INK44) + '</a>')
    years = ''.join('<span style="font-size: 15px; color: ' + (INK if y == '2026' else INK64) + '; font-weight: ' + ('500' if y == '2026' else '400') + ';">' + y + '</span>' for y in ['2026', '2025'])
    left = '<div style="display: flex; flex-direction: column; gap: 12px;">' + mono('年份', INK44) + years + '</div>\n'
    right = '<div style="display: flex; flex-direction: column; gap: 4px;">' + rows + '</div>\n'
    content = ('<div style="display: grid; grid-template-columns: 200px minmax(0, 1fr); gap: 56px; padding: 0 64px 80px 64px;">' + left + right + '</div>\n')
    return document(topbar('周刊') + header + content, 1440, 900)
