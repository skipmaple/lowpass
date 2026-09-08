"""第二轮方向：Terracotta、Riso、Claude 暖编辑，同一张日刊页。期头文楷、元数据 Maple Mono 三稿共用。"""
from common import *

def doc(body, fonts_href, canvas, ink, font_body, extra_css='', min_height=1300):
    helmet = ('<helmet>\n  <link rel="stylesheet" href="' + fonts_href + '">\n  <style>\n' + font_css()
              + '    body { margin: 0; }\n' + extra_css + '  </style>\n</helmet>\n')
    root = ('<div style="width: 1440px; min-height: ' + str(min_height) + 'px; box-sizing: border-box; background: ' + canvas + '; color: ' + ink
            + '; font-family: ' + font_body + '; font-size: 16px; line-height: 1.6;">\n')
    return ("<!doctype html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <script src=\"./support.js\"></script>\n</head>\n<body>\n<x-dc>\n"
            + helmet + root + body + "</div>\n</x-dc>\n</body>\n</html>\n")

def wrow(rank, title, meta, summary, f, sep=''):
    """一条条目。f 为该方向的样式字典。"""
    parts = ['<a href="#" style="font-family: ' + f['title_font'] + '; font-size: ' + str(f['title_size']) + 'px; font-weight: ' + str(f['title_weight'])
             + '; line-height: 1.45; color: ' + f['title_color'] + ';">' + title + '</a>']
    if summary:
        parts.append('<span style="font-family: ' + f['body_font'] + '; font-size: 14px; line-height: 1.55; color: ' + f['summary_color'] + ';">' + summary + '</span>')
    parts.append(mono(meta, f['meta_color']))
    return ('<article style="display: flex; gap: 14px; padding: ' + f['row_pad'] + ';' + sep + '">'
            '<span style="font-family: ' + f['rank_font'] + '; font-size: 14px; color: ' + f['rank_color'] + '; width: 26px; flex: none; padding-top: 3px;">' + rank + '</span>'
            '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0;">' + ''.join(parts) + '</div></article>\n')

def rows(items, f, sep_css):
    out = ''
    for i, it in enumerate(items):
        rank, title, meta = it[0], it[1], it[2]
        summary = it[3] if len(it) > 3 else None
        sep = sep_css if i < len(items) - 1 else ''
        out += wrow(rank, title, meta, summary, f, sep)
    return out

# ---------------------------------------------------------------- Terracotta
def terracotta():
    CREAM, WHITE, TEXT, BROWN, ACC = '#F3E9D8', '#FFFFFF', '#111827', '#3A2A1F', '#C56A3C'
    MUTED, META, HAIR = '#6F5B4C', '#7A6656', 'rgba(58, 42, 31, 0.14)'
    SERIF = "'DM Serif Display', 'Noto Serif SC', 'Songti SC', serif"
    SANS = "'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=Noto+Serif+SC:wght@400;600&family=Noto+Sans+SC:wght@400;500&display=swap'
    css = ('    a { color: ' + BROWN + '; text-decoration: none; }\n    a:hover { color: ' + ACC + '; text-decoration: underline; text-underline-offset: 3px; }\n')
    f = dict(title_font=SERIF, title_size=19, title_weight=400, title_color=BROWN, body_font=SANS, summary_color='#5C4A3D', meta_color=META,
             rank_font=SERIF, rank_color=ACC, row_pad='16px 0')
    sep = ' border-bottom: 1px solid ' + HAIR + ';'
    def nav(label, active):
        if active:
            return '<span style="font-family: ' + SANS + '; font-size: 15px; font-weight: 500; color: ' + BROWN + '; border-bottom: 2px solid ' + ACC + '; padding-bottom: 2px;">' + label + '</span>'
        return '<span style="font-family: ' + SANS + '; font-size: 15px; color: ' + MUTED + ';">' + label + '</span>'
    def btn(label, il=None, ir=None, disabled=False):
        col = 'rgba(58, 42, 31, 0.4)' if disabled else BROWN
        bd = 'rgba(58, 42, 31, 0.12)' if disabled else 'rgba(58, 42, 31, 0.28)'
        return ('<span style="display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 14px; border-radius: 8px; font-family: ' + SANS + '; font-size: 14px; font-weight: 500; color: ' + col + '; border: 1px solid ' + bd + '; box-sizing: border-box; white-space: nowrap;">'
                + (icon(il, 16, col) if il else '') + '<span>' + label + '</span>' + (icon(ir, 16, col) if ir else '') + '</span>')
    topbar = ('<div style="height: 64px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
              '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-family: ' + SERIF + '; font-size: 24px; color: ' + BROWN + ';">lowpass</span>'
              '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
              '<div style="display: flex; align-items: center; gap: 12px;">'
              '<div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 12px; background: ' + WHITE + '; border: 1px solid ' + HAIR + '; border-radius: 8px; box-sizing: border-box; color: ' + MUTED + '; font-family: ' + SANS + '; font-size: 14px;">' + icon('search', 18, MUTED) + '<span>搜标题、摘要或来源</span></div>'
              '<span style="width: 36px; height: 36px; border-radius: 50%; background: rgba(197, 106, 60, 0.18); display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 18, ACC) + '</span>'
              '</div></div>\n')
    header = ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 56px 64px 28px 64px;">'
              '<div style="display: flex; flex-direction: column; gap: 12px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', META)
              + '<h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: 48px; line-height: 1.1; color: ' + BROWN + '; display: flex; align-items: baseline; gap: 16px;"><span>9月8日</span><span style="font-size: 24px; color: ' + ACC + ';">星期二</span></h1></div>'
              '<div style="display: flex; gap: 8px; align-items: center;">' + btn('9月7日', il='chevron-left') + btn('归档') + btn('9月9日', ir='chevron-right', disabled=True) + '</div></div>\n'
              '<div style="height: 2px; background: ' + ACC + '; margin: 0 64px;"></div>\n')
    def chapter(title, count, items, more):
        return ('<section style="display: flex; flex-direction: column;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; padding-bottom: 12px; border-bottom: 1px solid ' + HAIR + ';">'
                + mono(title, ACC) + mono(count, META) + '</div>' + rows(items, f, sep)
                + '<a href="#" style="display: inline-flex; align-items: center; gap: 6px; margin-top: 16px; font-family: ' + SANS + '; font-size: 14px; font-weight: 500; color: ' + ACC + ';"><span>' + more + '</span>' + icon('arrow-right', 16, ACC) + '</a></section>\n')
    surface = ('<div style="margin: 32px 64px 64px 64px; background: ' + WHITE + '; border-radius: 8px; padding: 40px;">'
               '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 48px;">'
               + chapter('HACKER NEWS', '前 30 条', HN, '其余 22 条') + chapter('GITHUB TRENDING', '今日 25 个', GH, '其余 19 个') + chapter('HACKADAY', '近 24 小时 12 篇', HAD, '其余 6 篇')
               + '</div></div>\n')
    return doc(topbar + header + surface, fonts, CREAM, TEXT, SANS, css)

# ---------------------------------------------------------------- Riso
def riso():
    PAPER, WHITE, TEXT, PINK, BLUE = '#FAF6EE', '#FFFFFF', '#111827', '#F237A1', '#2C40A7'
    MUTED = '#5A5E73'
    GROT = "'Space Grotesk', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;700&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = ('    a { color: ' + TEXT + '; text-decoration: none; }\n    a:hover { color: ' + PINK + '; text-decoration: underline; text-underline-offset: 3px; text-decoration-thickness: 2px; }\n')
    f = dict(title_font=GROT, title_size=17, title_weight=500, title_color=TEXT, body_font=GROT, summary_color='#4B4F63', meta_color=BLUE,
             rank_font=MONO, rank_color=PINK, row_pad='14px 20px')
    sep = ' border-bottom: 1px dotted rgba(44, 64, 167, 0.35);'
    def nav(label, active):
        if active:
            return '<span style="font-size: 15px; font-weight: 700; color: ' + BLUE + '; border-bottom: 3px solid ' + PINK + '; padding-bottom: 2px;">' + label + '</span>'
        return '<span style="font-size: 15px; font-weight: 500; color: ' + MUTED + ';">' + label + '</span>'
    def btn(label, il=None, ir=None, disabled=False):
        if disabled:
            return ('<span style="display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 14px; border-radius: 4px; font-size: 14px; font-weight: 700; color: rgba(44, 64, 167, 0.4); border: 2px solid rgba(44, 64, 167, 0.25); box-sizing: border-box; white-space: nowrap;">'
                    + (icon(il, 16, 'rgba(44, 64, 167, 0.4)') if il else '') + '<span>' + label + '</span>' + (icon(ir, 16, 'rgba(44, 64, 167, 0.4)') if ir else '') + '</span>')
        return ('<span style="display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 14px; border-radius: 4px; font-size: 14px; font-weight: 700; color: ' + BLUE + '; background: ' + WHITE + '; border: 2px solid ' + BLUE + '; box-shadow: 3px 3px 0 ' + PINK + '; box-sizing: border-box; white-space: nowrap;">'
                + (icon(il, 16, BLUE) if il else '') + '<span>' + label + '</span>' + (icon(ir, 16, BLUE) if ir else '') + '</span>')
    topbar = ('<div style="height: 64px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px; border-bottom: 2px solid ' + BLUE + ';">'
              '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-size: 22px; font-weight: 700; color: ' + BLUE + '; letter-spacing: -0.02em;">lowpass</span>'
              '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
              '<div style="display: flex; align-items: center; gap: 16px;">'
              '<div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 12px; background: ' + WHITE + '; border: 2px solid ' + BLUE + '; border-radius: 4px; box-shadow: 3px 3px 0 ' + PINK + '; box-sizing: border-box; color: ' + MUTED + '; font-size: 14px;">' + icon('search', 18, BLUE) + '<span>搜标题、摘要或来源</span></div>'
              '<span style="width: 36px; height: 36px; border-radius: 50%; background: ' + BLUE + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 18, WHITE) + '</span>'
              '</div></div>\n')
    header = ('<div style="background-image: radial-gradient(rgba(44, 64, 167, 0.14) 1px, transparent 1px); background-size: 6px 6px;">'
              '<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 56px 64px 40px 64px;">'
              '<div style="display: flex; flex-direction: column; gap: 12px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', PINK)
              + '<h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: 56px; line-height: 1.1; color: ' + BLUE + '; text-shadow: 3px 3px 0 rgba(242, 55, 161, 0.6); display: flex; align-items: baseline; gap: 18px;"><span>9月8日</span><span style="font-size: 26px; color: ' + PINK + '; text-shadow: none;">星期二</span></h1></div>'
              '<div style="display: flex; gap: 10px; align-items: center;">' + btn('9月7日', il='chevron-left') + btn('归档') + btn('9月9日', ir='chevron-right', disabled=True) + '</div></div></div>\n')
    def block(title, count, items, more):
        return ('<section style="background: ' + WHITE + '; border: 2px solid ' + BLUE + '; border-radius: 4px; box-shadow: 6px 6px 0 ' + PINK + '; display: flex; flex-direction: column; overflow: hidden;">'
                '<div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 20px; background: ' + BLUE + '; color: ' + PAPER + ';">'
                '<span style="font-size: 13px; font-weight: 700; letter-spacing: 0.08em;">' + title + '</span>' + mono(count, PAPER) + '</div>'
                + rows(items, f, sep)
                + '<a href="#" style="display: inline-flex; align-items: center; gap: 6px; padding: 14px 20px; border-top: 2px solid ' + BLUE + '; font-size: 14px; font-weight: 700; color: ' + PINK + ';"><span>' + more + '</span>' + icon('arrow-right', 16, PINK) + '</a></section>\n')
    grid = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 40px; padding: 8px 64px 72px 64px;">'
            + block('HACKER NEWS', '前 30 条', HN, '其余 22 条') + block('GITHUB TRENDING', '今日 25 个', GH, '其余 19 个') + block('HACKADAY', '近 24 小时 12 篇', HAD, '其余 6 篇') + '</div>\n')
    return doc(topbar + header + grid, fonts, PAPER, TEXT, GROT, css)

# ---------------------------------------------------------------- Claude 暖编辑
def claude_warm():
    CANVAS, CARD, STRONG, INK, BODY, MUTED, SOFT, HAIR, CORAL, DARK, ONDARK = '#faf9f5', '#efe9de', '#e8e0d2', '#141413', '#3d3d3a', '#6c6a64', '#8e8b82', '#e6dfd8', '#cc785c', '#181715', '#a09d96'
    SERIF = "'Source Serif 4', 'Noto Serif SC', 'Songti SC', serif"
    SANS = "'Inter', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400&family=Inter:wght@400;500&family=Noto+Serif+SC:wght@400&family=Noto+Sans+SC:wght@400;500&display=swap'
    css = ('    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-underline-offset: 3px; }\n')
    f = dict(title_font=SERIF, title_size=18, title_weight=400, title_color=INK, body_font=SANS, summary_color=BODY, meta_color=MUTED,
             rank_font=MONO, rank_color=SOFT, row_pad='14px 0')
    sep = ' border-bottom: 1px solid ' + HAIR + ';'
    def nav(label, active):
        return '<span style="font-size: 14px; font-weight: 500; color: ' + (INK if active else MUTED) + ';">' + label + '</span>'
    def btn(label, il=None, ir=None, disabled=False):
        col = SOFT if disabled else INK
        return ('<span style="display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 20px; border-radius: 8px; font-size: 14px; font-weight: 500; color: ' + col + '; background: ' + CANVAS + '; border: 1px solid ' + HAIR + '; box-sizing: border-box; white-space: nowrap;">'
                + (icon(il, 16, col) if il else '') + '<span>' + label + '</span>' + (icon(ir, 16, col) if ir else '') + '</span>')
    topbar = ('<div style="height: 64px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px; max-width: 1312px;">'
              '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-family: ' + SERIF + '; font-size: 22px; color: ' + INK + ';">lowpass</span>'
              '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
              '<div style="display: flex; align-items: center; gap: 12px;">'
              '<div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 14px; background: ' + CANVAS + '; border: 1px solid ' + HAIR + '; border-radius: 8px; box-sizing: border-box; color: ' + SOFT + '; font-size: 14px;">' + icon('search', 18, MUTED) + '<span>搜标题、摘要或来源</span></div>'
              '<span style="width: 36px; height: 36px; border-radius: 9999px; background: ' + STRONG + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 18, MUTED) + '</span>'
              '</div></div>\n')
    header = ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 56px 64px 40px 64px;">'
              '<div style="display: flex; flex-direction: column; gap: 12px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', MUTED)
              + '<h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: 48px; line-height: 1.1; letter-spacing: -1px; color: ' + INK + '; display: flex; align-items: baseline; gap: 16px;"><span>9月8日</span><span style="font-size: 24px; color: ' + MUTED + '; letter-spacing: 0;">星期二</span></h1></div>'
              '<div style="display: flex; gap: 8px; align-items: center;">' + btn('9月7日', il='chevron-left') + btn('归档') + btn('9月9日', ir='chevron-right', disabled=True) + '</div></div>\n')
    def card(title, count, items, more):
        return ('<section style="background: ' + CARD + '; border-radius: 12px; padding: 32px; display: flex; flex-direction: column;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; padding-bottom: 8px;">'
                '<h2 style="margin: 0; font-size: 18px; font-weight: 500; line-height: 1.4; color: ' + INK + ';">' + title + '</h2>' + mono(count, MUTED) + '</div>'
                + rows(items, f, sep)
                + '<a href="#" style="display: inline-flex; align-items: center; gap: 6px; margin-top: 18px; font-size: 14px; font-weight: 500; color: ' + CORAL + ';"><span>' + more + '</span>' + icon('arrow-right', 16, CORAL) + '</a></section>\n')
    grid = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; padding: 0 64px 64px 64px;">'
            + card('Hacker News', '前 30 条', HN, '其余 22 条') + card('GitHub Trending', '今日 25 个', GH, '其余 19 个') + card('Hackaday', '近 24 小时 12 篇', HAD, '其余 6 篇') + '</div>\n')
    footer = ('<div style="background: ' + DARK + '; color: ' + ONDARK + '; padding: 32px 64px; display: flex; justify-content: space-between; align-items: center;">'
              '<span style="font-family: ' + SERIF + '; font-size: 18px; color: ' + CANVAS + ';">lowpass</span>' + mono('每日 06:00 装订 · 每周 09:00 查新期', ONDARK) + '</div>\n')
    return doc(topbar + header + grid + footer, fonts, CANVAS, INK, SANS, css)
