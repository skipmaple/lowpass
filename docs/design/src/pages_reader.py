from common import *

def _prev_next(prev_label, next_label):
    return (button(prev_label, 'outline', icon_left='chevron-left') + button('归档', 'outline')
            + button(next_label, 'outline', icon_right='chevron-right', disabled=True))

def login():
    btn = ('<span style="display: flex; align-items: center; justify-content: center; height: 44px; border: 1px solid ' + BORDER_STRONG
           + '; border-radius: 8px; font-size: 15px; font-weight: 500; background: #FFFFFF;">{}</span>')
    body = (
        '<div style="min-height: 900px; display: flex; align-items: center; justify-content: center;">\n'
        '  <div style="width: 360px; display: flex; flex-direction: column; gap: 40px;">\n'
        '    <span style="font-size: 16px; font-weight: 500;">lowpass</span>\n'
        '    <p style="margin: 0; font-family: ' + KAI + '; font-size: 30px; line-height: 1.4;">滤掉噪音，留下信号。</p>\n'
        '    <div style="display: flex; flex-direction: column; gap: 12px;">' + btn.format('使用 Google 登录') + btn.format('使用 GitHub 登录') + '</div>\n'
        '    <span style="font-size: 13px; color: ' + INK44 + ';">只需登录，不需要注册。</span>\n'
        '  </div>\n'
        '</div>\n'
    )
    return document(body, 1440, 900)

def home():
    controls = mono('日刊已于 06:12 发布 · 67 条') + button('阅读全部', 'outline', icon_right='arrow-right')
    header = issue_header('今天 · 2026-09-08', '9月8日', '星期二', controls)
    def chapter(title, count, rows, more):
        return '<section style="display: flex; flex-direction: column; gap: 20px;">' + chapter_head(title, count) + ''.join(rows) + more_link(more) + '</section>\n'
    grid = (
        '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 56px; padding: 0 64px;">\n'
        + chapter('Hacker News', '前 30 条', [row(r, t, m) for r, t, m in HN[:5]], '查看全部 30 条')
        + chapter('GitHub Trending', '今日 25 个', [row(r, t, m, s) for r, t, m, s in GH[:5]], '查看全部 25 个')
        + chapter('Hackaday', '近 24 小时 12 篇', [row(r, t, m) for r, t, m, s in HAD[:5]], '查看全部 12 篇')
        + '</div>\n'
    )
    weekly = (
        '<div style="padding: 96px 64px 80px 64px; display: flex; flex-direction: column; gap: 20px; max-width: 880px;">\n'
        + chapter_head('本周周刊', '第 36 周 · 9月1日 至 9月7日')
        + '<article style="display: flex; flex-direction: column; gap: 6px;">'
        '<a href="#" style="font-size: 16px; line-height: 1.5; color: #000000;">阮一峰周刊 · 第 366 期：把信号从噪音里捞出来</a>'
        '<span style="font-size: 15px; line-height: 1.5; color: ' + INK64 + ';">本周话题、科技动态、文章、工具、资源、图片、文摘、言论，共 52 条。</span>'
        + mono('9月5日 发布') + '</article>\n'
        + more_link('阅读本周周刊')
        + '</div>\n'
    )
    return document(topbar(active='') + header + grid + weekly, 1440, 1120)

def daily():
    controls = _prev_next('9月7日', '9月9日')
    header = issue_header('日刊 · 2026-09-08 · 06:12 发布', '9月8日', '星期二', controls)
    def chapter(title, count, rows, more):
        return '<section style="display: flex; flex-direction: column; gap: 20px;">' + chapter_head(title, count) + ''.join(rows) + more_link(more) + '</section>\n'
    grid = (
        '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 56px; padding: 0 64px 80px 64px;">\n'
        + chapter('Hacker News', '前 30 条', [row(r, t, m) for r, t, m in HN], '其余 22 条')
        + chapter('GitHub Trending', '今日 25 个', [row(r, t, m, s) for r, t, m, s in GH], '其余 19 个')
        + chapter('Hackaday', '近 24 小时 12 篇', [row(r, t, m, s) for r, t, m, s in HAD], '其余 6 篇')
        + '</div>\n'
    )
    return document(topbar('日刊') + header + grid, 1440, 1280)

def _tabs(active, labels):
    out = []
    for l in labels:
        if l == active:
            out.append('<span style="padding: 10px 0; font-size: 15px; font-weight: 500; color: #000000; border-bottom: 2px solid #000000; margin-bottom: -1px;">' + l + '</span>')
        else:
            out.append('<span style="padding: 10px 0; font-size: 15px; color: ' + INK64 + ';">' + l + '</span>')
    return '<div style="display: flex; gap: 24px; border-bottom: 1px solid ' + BORDER + ';">' + ''.join(out) + '</div>\n'

def daily_mobile():
    header = (
        '<div style="display: flex; flex-direction: column; gap: 10px; padding: 20px 24px 8px 24px;">\n'
        '  ' + mono('日刊 · 2026-09-08 · 06:12 发布') + '\n'
        '  <h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: 34px; line-height: 1.1; display: flex; align-items: baseline; gap: 12px;">'
        '<span>9月8日</span><span style="font-size: 17px; color: ' + INK64 + ';">星期二</span></h1>\n'
        '</div>\n'
        '<div style="display: flex; gap: 4px; padding: 8px 16px 16px 16px;">'
        + button('9月7日', 'ghost', icon_left='chevron-left', height=36) + button('归档', 'ghost', height=36)
        + button('9月9日', 'ghost', icon_right='chevron-right', height=36, disabled=True) + '</div>\n'
    )
    tabs = '<div style="padding: 0 24px;">' + _tabs('Hacker News', ['Hacker News', 'GitHub', 'Hackaday']) + '</div>\n'
    rows = ''.join(row(r, t, m, rank_width=24) for r, t, m in HN[:7])
    lst = ('<div style="display: flex; flex-direction: column; gap: 20px; padding: 24px 24px 40px 24px;">' + rows + more_link('其余 23 条') + '</div>\n')
    return document(topbar_mobile() + header + tabs + lst, 390, 1160)

def daily_archive():
    controls = button('8月', 'outline', icon_left='chevron-left') + button('10月', 'outline', icon_right='chevron-right', disabled=True)
    header = issue_header('日刊归档', '2026 年 9 月', '', controls)
    months = ''.join(
        '<span style="font-size: 15px; color: ' + (INK if m == '9月' else INK64) + '; font-weight: ' + ('500' if m == '9月' else '400') + ';">' + m + '</span>'
        for m in ['9月', '8月', '7月', '6月', '5月']
    )
    left = ('<div style="display: flex; flex-direction: column; gap: 12px;">' + mono('2026', INK44) + months + '</div>\n')
    dot_ok = '<span style="width: 8px; height: 8px; border-radius: 50%; background: #000000; display: inline-block;"></span>'
    dot_empty = '<span style="width: 8px; height: 8px; border-radius: 50%; border: 1.5px solid ' + INK44 + '; box-sizing: border-box; display: inline-block;"></span>'
    dot_missing = '<span style="width: 8px; height: 8px; border-radius: 50%; border: 1.5px dashed ' + INK44 + '; box-sizing: border-box; display: inline-block;"></span>'
    days = [
        ('9月8日 · 周二', dot_ok, '06:12 发布 · 67 条', INK),
        ('9月7日 · 周一', dot_ok, '06:09 发布 · 71 条', INK),
        ('9月6日 · 周日', dot_ok, '06:11 发布 · 58 条', INK),
        ('9月5日 · 周六', dot_ok, '06:10 发布 · 63 条', INK),
        ('9月4日 · 周五', dot_ok, '06:14 发布 · 69 条', INK),
        ('9月3日 · 周四', dot_empty, '空刊 · 所有来源抓取失败', INK64),
        ('9月2日 · 周三', dot_ok, '07:05 延迟生成 · 64 条', INK),
        ('9月1日 · 周二', dot_missing, '本期未生成', INK64),
    ]
    rows = ''
    for i, (d, dot, meta, col) in enumerate(days):
        bg = ALT if i % 2 == 1 else 'transparent'
        rows += ('<a href="#" style="display: grid; grid-template-columns: 180px 12px minmax(0, 1fr) 20px; gap: 16px; align-items: center; padding: 14px 12px; border-radius: 8px; background: ' + bg + '; color: ' + col + ';">'
                 '<span style="font-size: 16px;">' + d + '</span>' + dot + mono(meta) + icon('chevron-right', 18, INK44) + '</a>')
    legend = ('<div style="display: flex; gap: 24px; padding-top: 24px;">'
              '<span style="display: inline-flex; align-items: center; gap: 8px;">' + dot_ok + mono('已发布', INK44) + '</span>'
              '<span style="display: inline-flex; align-items: center; gap: 8px;">' + dot_empty + mono('空刊', INK44) + '</span>'
              '<span style="display: inline-flex; align-items: center; gap: 8px;">' + dot_missing + mono('未生成', INK44) + '</span></div>')
    right = '<div style="display: flex; flex-direction: column; gap: 4px;">' + rows + legend + '</div>\n'
    content = ('<div style="display: grid; grid-template-columns: 200px minmax(0, 1fr); gap: 56px; padding: 0 64px 80px 64px;">' + left + right + '</div>\n')
    return document(topbar('日刊') + header + content, 1440, 1000)
