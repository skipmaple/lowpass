"""第四轮：简洁、有温度、有设计感。六种版面结构，统一白底加杏橙点缀，Instrument Sans。"""
from common import *
from pages_warm import doc

WHITE, INK, BODY, MUTED, META, HAIR, HAIR2 = '#FFFFFF', '#1C1C1C', '#3C3C3C', '#6E6E6E', '#757575', '#E9E9E9', '#F2F2F2'
ACC, ACCT, TINT, TINT2 = '#F26B3A', '#B8461C', '#FFF1EA', '#FFE3D5'
SANS = "'Instrument Sans', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
FONTS = 'https://fonts.googleapis.com/css2?family=Instrument+Sans:wght@400;500;600&family=Noto+Sans+SC:wght@400;500;700&display=swap'
CSS = '    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + ACCT + '; text-decoration: underline; text-underline-offset: 3px; }\n'
H = 2000

def page(body):
    return doc(body, FONTS, WHITE, INK, SANS, CSS, H)

def nav(label, active):
    if active:
        return '<span style="font-size: 14px; font-weight: 600; color: ' + INK + '; border-bottom: 2px solid ' + ACC + '; padding-bottom: 3px;">' + label + '</span>'
    return '<span style="font-size: 14px; font-weight: 500; color: ' + MUTED + ';">' + label + '</span>'

def topbar(active='日刊', pad='0 64px'):
    return ('<div style="height: 64px; display: flex; align-items: center; justify-content: space-between; padding: ' + pad + ';">'
            '<div style="display: flex; align-items: center; gap: 36px;"><span style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em;">lowpass</span>'
            '<div style="display: flex; gap: 24px;">' + nav('日刊', active == '日刊') + nav('周刊', active == '周刊') + nav('搜索', active == '搜索') + '</div></div>'
            '<div style="display: flex; align-items: center; gap: 16px;">' + icon('search', 20, MUTED)
            + '<span style="width: 32px; height: 32px; border-radius: 50%; background: ' + TINT + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 16, ACCT) + '</span></div></div>\n')

def item(rank, title, meta, summary=None, size=16, gap=14):
    parts = ['<a href="#" style="font-size: ' + str(size) + 'px; font-weight: 500; line-height: 1.45; color: ' + INK + ';">' + title + '</a>']
    if summary:
        parts.append('<span style="font-size: 14px; line-height: 1.5; color: ' + MUTED + ';">' + summary + '</span>')
    parts.append(mono(meta, META))
    return ('<article style="display: flex; gap: ' + str(gap) + 'px;">' + mono(rank, ACCT).replace('<span style="', '<span style="width: 24px; flex: none; padding-top: 3px; ')
            + '<div style="display: flex; flex-direction: column; gap: 5px; min-width: 0;">' + ''.join(parts) + '</div></article>')

def more(label):
    return '<a href="#" style="display: inline-flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 500; color: ' + ACCT + ';"><span>' + label + '</span>' + icon('arrow-right', 16, ACCT) + '</a>'

def wk(text, size, color=INK, extra=''):
    return '<span style="font-family: ' + KAI + '; font-size: ' + str(size) + 'px; line-height: 1; color: ' + color + ';' + extra + '">' + text + '</span>'

SRC = [('Hacker News', 30, HN, '条'), ('GitHub Trending', 25, GH, '个'), ('Hackaday', 12, HAD, '篇')]

def col(title, total, items, unit, n, with_summary, size=15, gap_rows=14):
    shown = items[:n]
    rows = ''.join(item(r[0], r[1], r[2], (r[3] if with_summary and len(r) > 3 else None), size) for r in shown)
    return ('<section style="display: flex; flex-direction: column; gap: ' + str(gap_rows) + 'px;">'
            '<div style="display: flex; justify-content: space-between; align-items: baseline; padding-bottom: 10px; border-bottom: 1px solid ' + HAIR + ';"><h2 style="margin: 0; font-size: 14px; font-weight: 600; color: ' + INK + ';">' + title + '</h2>' + mono(str(total) + ' ' + unit, META) + '</div>'
            + rows + '<div style="padding-top: 4px;">' + more('其余 ' + str(total - n) + ' ' + unit) + '</div></section>')

# 1 海报报头 ---------------------------------------------------------------
def poster():
    index_rows = ''.join(
        '<div style="display: grid; grid-template-columns: 24px minmax(0, 1fr) auto; gap: 16px; align-items: baseline; padding: 18px 0; border-bottom: 1px solid ' + HAIR + ';">'
        '<span style="width: 8px; height: 8px; border-radius: 50%; background: ' + (ACC if i == 0 else HAIR) + '; display: inline-block; align-self: center;"></span>'
        '<span style="font-size: 22px; font-weight: 500; color: ' + INK + ';">' + t + '</span>' + mono(str(n) + ' ' + u, META) + '</div>'
        for i, (t, n, _, u) in enumerate(SRC))
    header = ('<div style="display: grid; grid-template-columns: 5fr 7fr; gap: 64px; padding: 48px 64px 40px 64px; align-items: end;">'
              '<div style="display: flex; flex-direction: column; gap: 20px;">' + mono('日刊 · 06:12 发布 · 67 条', ACCT)
              + '<div style="display: flex; flex-direction: column; gap: 12px;">' + wk('9月8日', 168, INK, ' letter-spacing: -0.03em;') + wk('星期二 · 二〇二六', 28, MUTED) + '</div></div>'
              '<div style="display: flex; flex-direction: column;"><div style="padding-bottom: 6px;">' + mono('今日来源', META) + '</div>' + index_rows
              + '<div style="display: flex; gap: 20px; padding-top: 20px;">' + '<a href="#" style="font-size: 14px; font-weight: 500; color: ' + MUTED + ';">← 9月7日</a><a href="#" style="font-size: 14px; font-weight: 500; color: ' + MUTED + ';">归档</a></div></div></div>\n')
    grid = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 48px; padding: 24px 64px 48px 64px; border-top: 2px solid ' + INK + ';">'
            + col('Hacker News', 30, HN, '条', 8, False) + col('GitHub Trending', 25, GH, '个', 6, True) + col('Hackaday', 12, HAD, '篇', 6, True) + '</div>\n')
    foot = '<div style="display: flex; justify-content: space-between; padding: 20px 64px 48px 64px; border-top: 1px solid ' + HAIR + ';">' + mono('lowpass', META) + mono('明早 06:00 下一期', META) + '</div>\n'
    return page(topbar() + header + grid + foot)

# 2 左栏固定 ---------------------------------------------------------------
def split():
    def side_nav(label, n, unit, active):
        return ('<a href="#" style="display: flex; justify-content: space-between; align-items: baseline; padding: 12px 0; border-bottom: 1px solid ' + TINT2 + '; color: ' + (INK if active else BODY) + '; font-size: 16px; font-weight: ' + ('600' if active else '500') + ';">'
                '<span>' + label + '</span>' + mono(str(n) + ' ' + unit, ACCT if active else MUTED) + '</a>')
    left = ('<div style="width: 420px; flex: none; background: ' + TINT + '; min-height: ' + str(H) + 'px; padding: 40px; box-sizing: border-box; display: flex; flex-direction: column; gap: 40px;">'
            '<span style="font-size: 16px; font-weight: 600;">lowpass</span>'
            '<div style="display: flex; flex-direction: column; gap: 16px;">' + mono('日刊 · 2026-09-08', ACCT) + wk('9月8日', 80, INK, ' letter-spacing: -0.02em;') + wk('星期二', 26, MUTED) + mono('06:12 发布 · 67 条', MUTED) + '</div>'
            '<div style="display: flex; flex-direction: column;">' + side_nav('Hacker News', 30, '条', True) + side_nav('GitHub Trending', 25, '个', False) + side_nav('Hackaday', 12, '篇', False) + '</div>'
            '<div style="display: flex; gap: 8px;">'
            '<span style="display: inline-flex; align-items: center; justify-content: center; width: 40px; height: 40px; border-radius: 50%; background: ' + WHITE + ';">' + icon('chevron-left', 18, INK) + '</span>'
            '<span style="display: inline-flex; align-items: center; justify-content: center; width: 40px; height: 40px; border-radius: 50%; background: ' + WHITE + '; opacity: 0.45;">' + icon('chevron-right', 18, INK) + '</span>'
            '<span style="display: inline-flex; align-items: center; height: 40px; padding: 0 16px; border-radius: 999px; background: ' + WHITE + '; font-size: 14px; font-weight: 500;">归档</span></div>'
            '<div style="flex: 1;"></div>'
            '<div style="display: flex; flex-direction: column; gap: 6px;">' + mono('本周周刊 · 第 36 周', MUTED) + '<a href="#" style="font-size: 16px; font-weight: 500;">阮一峰周刊 · 第 366 期 →</a></div>'
            '<div style="display: flex; gap: 20px; font-size: 14px; color: ' + MUTED + ';"><span>周刊</span><span>搜索</span><span>设置</span></div></div>\n')
    def chapter(title, total, items, unit, n, with_summary):
        rows = ''.join('<div style="padding: 16px 0; border-bottom: 1px solid ' + HAIR + ';">' + item(r[0], r[1], r[2], (r[3] if with_summary and len(r) > 3 else None), 17, 20) + '</div>' for r in items[:n])
        return ('<section style="display: flex; flex-direction: column;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; padding-bottom: 8px;"><h2 style="margin: 0; font-size: 22px; font-weight: 600; letter-spacing: -0.01em;">' + title + '</h2>' + mono(str(total) + ' ' + unit, META) + '</div>'
                + rows + '<div style="padding-top: 16px;">' + more('其余 ' + str(total - n) + ' ' + unit) + '</div></section>')
    right = ('<div style="flex: 1; min-width: 0; padding: 56px 64px 64px 64px; display: flex; flex-direction: column; gap: 56px; max-width: 880px;">'
             + chapter('Hacker News', 30, HN, '条', 6, False) + chapter('GitHub Trending', 25, GH, '个', 4, True) + chapter('Hackaday', 12, HAD, '篇', 4, True) + '</div>\n')
    return page('<div style="display: flex;">' + left + right + '</div>')

# 3 封面加目录 -------------------------------------------------------------
def cover():
    ledes = [(HN[0][1], 'Hacker News · ▲ 312'), (GH[0][1] + ' · ' + GH[0][3], 'GitHub Trending · ★ 12.3k'), (HAD[0][1], 'Hackaday · M. Okada')]
    lede_rows = ''.join('<div style="display: flex; flex-direction: column; gap: 6px; padding: 16px 0; border-bottom: 1px solid ' + TINT2 + ';">'
                        '<a href="#" style="font-size: 21px; font-weight: 500; line-height: 1.4;">' + t + '</a>' + mono(m, ACCT) + '</div>' for t, m in ledes)
    cover_block = ('<div style="margin: 8px 64px 0 64px; background: ' + TINT + '; border-radius: 24px; padding: 56px; display: grid; grid-template-columns: 5fr 7fr; gap: 64px; align-items: start;">'
                   '<div style="display: flex; flex-direction: column; gap: 18px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', ACCT) + wk('9月8日', 104, INK, ' letter-spacing: -0.03em;') + wk('星期二', 28, MUTED)
                   + '<div style="display: flex; gap: 20px; padding-top: 12px;"><a href="#" style="font-size: 14px; font-weight: 500; color: ' + BODY + ';">← 9月7日</a><a href="#" style="font-size: 14px; font-weight: 500; color: ' + BODY + ';">归档</a></div></div>'
                   '<div style="display: flex; flex-direction: column;"><span style="font-size: 13px; font-weight: 600; color: ' + ACCT + '; padding-bottom: 4px;">今日看点</span>' + lede_rows + '</div></div>\n')
    grid = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 48px; padding: 56px 64px 64px 64px;">'
            + col('Hacker News', 30, HN, '条', 8, False) + col('GitHub Trending', 25, GH, '个', 6, True) + col('Hackaday', 12, HAD, '篇', 6, True) + '</div>\n')
    return page(topbar() + cover_block + grid)

# 4 便当格 -----------------------------------------------------------------
def bento():
    tile = 'border-radius: 20px; padding: 28px; box-sizing: border-box; display: flex; flex-direction: column;'
    def list_tile(title, total, items, unit, n, with_summary, span, two_col=False):
        rows_html = ''.join(item(r[0], r[1], r[2], (r[3] if with_summary and len(r) > 3 else None), 15) for r in items[:n])
        body = ('<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px 32px;">' + rows_html + '</div>' if two_col
                else '<div style="display: flex; flex-direction: column; gap: 14px;">' + rows_html + '</div>')
        return ('<section style="' + tile + ' grid-column: span ' + str(span) + '; background: ' + WHITE + '; border: 1px solid ' + HAIR + '; gap: 18px;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline;"><h2 style="margin: 0; font-size: 15px; font-weight: 600;">' + title + '</h2>' + mono(str(total) + ' ' + unit, META) + '</div>'
                + body + '<div>' + more('其余 ' + str(total - n) + ' ' + unit) + '</div></section>')
    date_tile = ('<div style="' + tile + ' grid-column: span 4; background: ' + TINT + '; justify-content: space-between; gap: 40px;">'
                 '<div style="display: flex; flex-direction: column; gap: 14px;">' + mono('日刊 · 2026-09-08', ACCT) + wk('9月8日', 80, INK, ' letter-spacing: -0.02em;') + wk('星期二', 24, MUTED) + '</div>'
                 '<div style="display: flex; justify-content: space-between; align-items: center;">' + mono('06:12 发布', MUTED) + '<div style="display: flex; gap: 8px;">'
                 '<span style="display: inline-flex; align-items: center; justify-content: center; width: 36px; height: 36px; border-radius: 50%; background: ' + WHITE + ';">' + icon('chevron-left', 16, INK) + '</span>'
                 '<span style="display: inline-flex; align-items: center; justify-content: center; width: 36px; height: 36px; border-radius: 50%; background: ' + WHITE + '; opacity: 0.45;">' + icon('chevron-right', 16, INK) + '</span></div></div></div>')
    stat_tile = ('<div style="' + tile + ' grid-column: span 2; background: ' + HAIR2 + '; justify-content: space-between; gap: 24px;">' + mono('今日', MUTED)
                 + '<div style="display: flex; align-items: baseline; gap: 6px;"><span style="font-size: 64px; font-weight: 600; line-height: 1; letter-spacing: -0.04em;">67</span><span style="font-size: 16px; color: ' + MUTED + ';">条</span></div>' + mono('3 个来源', MUTED) + '</div>')
    week_tile = ('<div style="' + tile + ' grid-column: span 2; background: ' + HAIR2 + '; justify-content: space-between; gap: 24px;">' + mono('本周周刊', MUTED)
                 + '<a href="#" style="font-size: 17px; font-weight: 500; line-height: 1.4;">第 36 周 · 阮一峰周刊第 366 期</a>' + more('阅读') + '</div>')
    grid = ('<div style="display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: 16px; padding: 8px 64px 64px 64px;">'
            + date_tile + list_tile('Hacker News', 30, HN, '条', 8, False, 8, two_col=True)
            + stat_tile + week_tile + list_tile('GitHub Trending', 25, GH, '个', 5, True, 4) + list_tile('Hackaday', 12, HAD, '篇', 5, True, 4) + '</div>\n')
    return page(topbar() + grid)

# 5 早间轴 ------------------------------------------------------------------
def rail():
    def node(label, filled=False):
        dot = ('<span style="width: 14px; height: 14px; border-radius: 50%; background: radial-gradient(circle at 35% 35%, #FFB27A, ' + ACC + '); display: inline-block; flex: none;"></span>' if filled
               else '<span style="width: 12px; height: 12px; border-radius: 50%; border: 2px solid ' + ACC + '; background: ' + WHITE + '; box-sizing: border-box; display: inline-block; flex: none;"></span>')
        return '<div style="display: flex; align-items: center; gap: 16px; margin-left: -7px;">' + dot + mono(label, META) + '</div>'
    def chapter(title, total, items, unit, n, with_summary):
        rows = ''.join(item(r[0], r[1], r[2], (r[3] if with_summary and len(r) > 3 else None), 16, 16) for r in items[:n])
        return ('<section style="display: flex; flex-direction: column; gap: 18px; padding: 8px 0 32px 40px;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline;"><h2 style="margin: 0; font-size: 20px; font-weight: 600; letter-spacing: -0.01em;">' + title + '</h2>' + mono(str(total) + ' ' + unit, META) + '</div>'
                + rows + '<div style="padding-top: 4px;">' + more('其余 ' + str(total - n) + ' ' + unit) + '</div></section>')
    header = ('<div style="display: flex; flex-direction: column; gap: 16px; padding: 48px 0 40px 40px;">' + wk('9月8日', 72, INK, ' letter-spacing: -0.02em;') + wk('星期二', 24, MUTED) + '</div>')
    body = ('<div style="display: flex; justify-content: center; padding: 8px 64px 64px 64px;"><div style="width: 760px; border-left: 1px solid ' + HAIR + '; display: flex; flex-direction: column;">'
            + node('06:12 装订', True) + header
            + node('Hacker News') + chapter('Hacker News', 30, HN, '条', 6, False)
            + node('GitHub Trending') + chapter('GitHub Trending', 25, GH, '个', 4, True)
            + node('Hackaday') + chapter('Hackaday', 12, HAD, '篇', 4, True)
            + node('明早 06:00 下一期') + '</div></div>\n')
    return page(topbar() + body)

# 6 手账 --------------------------------------------------------------------
def journal():
    def line(rank, title, meta, summary=None):
        left = ('<div style="display: flex; gap: 14px; min-width: 0;"><span style="width: 8px; height: 8px; border-radius: 50%; background: ' + ACC + '; display: inline-block; flex: none; margin-top: 9px;"></span>'
                '<div style="display: flex; flex-direction: column; gap: 4px; min-width: 0;"><a href="#" style="font-size: 17px; font-weight: 500; line-height: 1.5;">' + title + '</a>'
                + ('<span style="font-size: 14px; line-height: 1.5; color: ' + MUTED + ';">' + summary + '</span>' if summary else '') + '</div></div>')
        right = '<div style="padding-top: 5px;">' + mono(rank + '  ' + meta, META) + '</div>'
        return '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 260px; gap: 32px; padding: 14px 0; border-bottom: 1px dotted #D6D6D6;">' + left + right + '</div>'
    def chapter(title, total, items, unit, n, with_summary):
        rows = ''.join(line(r[0], r[1], r[2], (r[3] if with_summary and len(r) > 3 else None)) for r in items[:n])
        return ('<section style="display: flex; flex-direction: column; padding-top: 40px;">'
                '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 260px; gap: 32px; align-items: baseline; padding-bottom: 8px;">' + wk(title, 26, INK) + mono(str(total) + ' ' + unit + ' · 显示 ' + str(n), META) + '</div>'
                + rows + '<div style="padding-top: 14px;">' + more('其余 ' + str(total - n) + ' ' + unit) + '</div></section>')
    header = ('<div style="background-image: radial-gradient(#E6E6E6 1px, transparent 1px); background-size: 20px 20px; padding: 56px 64px 40px 64px;">'
              '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 260px; gap: 32px; align-items: end;">'
              '<div style="display: flex; flex-direction: column; gap: 14px;">' + wk('九月八日', 64, INK) + wk('星期二 · 日刊', 24, MUTED) + '</div>'
              '<div style="display: flex; flex-direction: column; gap: 8px;">' + mono('2026-09-08', META) + mono('06:12 发布 · 67 条', META) + mono('← 09-07 · 归档', ACCT) + '</div></div></div>\n')
    body = ('<div style="padding: 0 64px 64px 64px; max-width: 1100px;">' + chapter('Hacker News', 30, HN, '条', 6, False) + chapter('GitHub Trending', 25, GH, '个', 4, True) + chapter('Hackaday', 12, HAD, '篇', 4, True) + '</div>\n')
    return page(topbar() + header + body)
