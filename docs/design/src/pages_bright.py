"""第三轮：六个明亮、温暖、积极的方向，同一张日刊页。共用文楷期头与 Maple Mono 元数据。"""
from common import *
from pages_warm import doc, rows

def search_field(bg, border, radius, color, icon_color):
    return ('<div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 14px; background: ' + bg + '; border: ' + border
            + '; border-radius: ' + radius + '; box-sizing: border-box; color: ' + color + '; font-size: 14px;">' + icon('search', 18, icon_color) + '<span>搜标题、摘要或来源</span></div>')

def avatar(bg, fg):
    return '<span style="width: 36px; height: 36px; border-radius: 50%; background: ' + bg + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 18, fg) + '</span>'

def button(label, style, icon_color, il=None, ir=None):
    return ('<span style="display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 16px; font-size: 14px; box-sizing: border-box; white-space: nowrap; ' + style + '">'
            + (icon(il, 16, icon_color) if il else '') + '<span>' + label + '</span>' + (icon(ir, 16, icon_color) if ir else '') + '</span>')

def controls(btn, btn_disabled):
    return '<div style="display: flex; gap: 8px; align-items: center;">' + btn('9月7日', 'chevron-left', None) + btn('归档', None, None) + btn_disabled('9月9日', None, 'chevron-right') + '</div>'

def date_h1(color, weekday_color, size=48, extra=''):
    return ('<h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: ' + str(size) + 'px; line-height: 1.1; color: ' + color + '; display: flex; align-items: baseline; gap: 16px;' + extra + '">'
            '<span>9月8日</span><span style="font-size: ' + str(size // 2) + 'px; color: ' + weekday_color + ';">星期二</span></h1>')

def more(label, color, weight=600, extra=''):
    return ('<a href="#" style="display: inline-flex; align-items: center; gap: 6px; font-size: 14px; font-weight: ' + str(weight) + '; color: ' + color + ';' + extra + '"><span>' + label + '</span>' + icon('arrow-right', 16, color) + '</a>')

SOURCES = [('Hacker News', '前 30 条', HN, '其余 22 条'), ('GitHub Trending', '今日 25 个', GH, '其余 19 个'), ('Hackaday', '近 24 小时 12 篇', HAD, '其余 6 篇')]

# 1 晨光 ----------------------------------------------------------------
def sunrise():
    INK, MUTED, META, ACC, ACCT, SOFT, FIELD = '#1A1A1A', '#6B6B6B', '#707070', '#F97316', '#C2410C', '#FFEDD5', '#F5F5F5'
    SANS = "'Manrope', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = '    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + ACCT + '; text-decoration: underline; text-underline-offset: 3px; }\n'
    f = dict(title_font=SANS, title_size=16, title_weight=600, title_color=INK, body_font=SANS, summary_color=MUTED, meta_color=META, rank_font=MONO, rank_color=ACCT, row_pad='9px 0')
    btn = lambda l, il, ir: button(l, 'border-radius: 10px; background: ' + FIELD + '; color: ' + INK + '; font-weight: 600;', INK, il, ir)
    btnd = lambda l, il, ir: button(l, 'border-radius: 10px; background: ' + FIELD + '; color: #BDBDBD; font-weight: 600;', '#BDBDBD', il, ir)
    nav = lambda l, a: ('<span style="font-size: 15px; font-weight: 600; color: ' + INK + '; border-bottom: 2px solid ' + ACC + '; padding-bottom: 3px;">' + l + '</span>' if a
                        else '<span style="font-size: 15px; font-weight: 500; color: ' + MUTED + ';">' + l + '</span>')
    top = ('<div style="height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
           '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-size: 18px; font-weight: 700; letter-spacing: -0.02em;">lowpass</span>'
           '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
           '<div style="display: flex; align-items: center; gap: 12px;">' + search_field(FIELD, 'none', '10px', MUTED, MUTED) + avatar(SOFT, ACC) + '</div></div>\n')
    head = ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 64px 64px 48px 64px;">'
            '<div style="display: flex; flex-direction: column; gap: 14px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', META) + date_h1(INK, ACCT) + '</div>' + controls(btn, btnd) + '</div>\n')
    def chapter(i, title, count, items, mr):
        return ('<section style="display: flex; flex-direction: column;">'
                '<span style="display: block; width: 32px; height: 4px; border-radius: 2px; background: ' + ACC + '; margin-bottom: 14px;"></span>'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px;"><h2 style="margin: 0; font-size: 17px; font-weight: 700; color: ' + INK + ';">' + title + '</h2>' + mono(count, META) + '</div>'
                + rows(items, f, '') + '<div style="margin-top: 16px;">' + more(mr, ACCT) + '</div></section>\n')
    grid = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 56px; padding: 0 64px 72px 64px;">' + ''.join(chapter(i, *s) for i, s in enumerate(SOURCES)) + '</div>\n'
    return doc(top + head + grid, fonts, '#FFFFFF', INK, SANS, css)

# 2 来源分色 --------------------------------------------------------------
def sources():
    INK, MUTED, META, LINE, FIELD = '#17181C', '#6F7480', '#6F7480', '#EEF0F3', '#F2F3F5'
    HUES = [('#C2410C', '#FFF0E5'), ('#15803D', '#EAF7EE'), ('#854D0E', '#FFF6D6')]
    SANS = "'Plus Jakarta Sans', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = '    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-underline-offset: 3px; }\n'
    btn = lambda l, il, ir: button(l, 'border-radius: 10px; border: 1px solid #E5E7EB; background: #FFFFFF; color: ' + INK + '; font-weight: 600;', INK, il, ir)
    btnd = lambda l, il, ir: button(l, 'border-radius: 10px; border: 1px solid ' + LINE + '; background: #FFFFFF; color: #B8BCC5; font-weight: 600;', '#B8BCC5', il, ir)
    nav = lambda l, a: ('<span style="font-size: 14px; font-weight: 700; color: ' + INK + '; background: ' + FIELD + '; border-radius: 999px; padding: 6px 14px;">' + l + '</span>' if a
                        else '<span style="font-size: 14px; font-weight: 600; color: ' + MUTED + '; padding: 6px 14px;">' + l + '</span>')
    top = ('<div style="height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
           '<div style="display: flex; align-items: center; gap: 32px;"><span style="font-size: 18px; font-weight: 800; letter-spacing: -0.02em;">lowpass</span>'
           '<div style="display: flex; gap: 4px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
           '<div style="display: flex; align-items: center; gap: 12px;">' + search_field('#FFFFFF', '1px solid #E5E7EB', '10px', MUTED, MUTED) + avatar(FIELD, MUTED) + '</div></div>\n')
    head = ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 56px 64px 40px 64px;">'
            '<div style="display: flex; flex-direction: column; gap: 14px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', META) + date_h1(INK, MUTED) + '</div>' + controls(btn, btnd) + '</div>\n')
    def chapter(i, title, count, items, mr):
        hue, tint = HUES[i]
        f = dict(title_font=SANS, title_size=16, title_weight=600, title_color=INK, body_font=SANS, summary_color=MUTED, meta_color=META, rank_font=MONO, rank_color=hue, row_pad='12px 20px')
        return ('<section style="display: flex; flex-direction: column; border: 1px solid ' + LINE + '; border-radius: 16px; overflow: hidden;">'
                '<div style="display: flex; justify-content: space-between; align-items: center; padding: 14px 20px; background: ' + tint + ';">'
                '<h2 style="margin: 0; font-size: 15px; font-weight: 700; color: ' + hue + ';">' + title + '</h2>' + mono(count, hue) + '</div>'
                + rows(items, f, ' border-bottom: 1px solid ' + LINE + ';') + '<div style="padding: 14px 20px; border-top: 1px solid ' + LINE + ';">' + more(mr, hue) + '</div></section>\n')
    grid = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; padding: 0 64px 72px 64px;">' + ''.join(chapter(i, *s) for i, s in enumerate(SOURCES)) + '</div>\n'
    return doc(top + head + grid, fonts, '#FFFFFF', INK, SANS, css)

# 3 柑橘渐变 --------------------------------------------------------------
def citrus():
    INK, MUTED, META, ACC, DEEP = '#1F1F1F', '#737373', '#737373', '#B45309', '#C2410C'
    SANS = "'Outfit', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = '    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + DEEP + '; text-decoration: underline; text-underline-offset: 3px; }\n'
    f = dict(title_font=SANS, title_size=16, title_weight=500, title_color=INK, body_font=SANS, summary_color=MUTED, meta_color=META, rank_font=MONO, rank_color=ACC, row_pad='10px 0')
    pill = 'border-radius: 999px; background: #FFFFFF; border: 1px solid rgba(0, 0, 0, 0.08); box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06); font-weight: 600;'
    btn = lambda l, il, ir: button(l, pill + ' color: ' + INK + ';', INK, il, ir)
    btnd = lambda l, il, ir: button(l, 'border-radius: 999px; background: rgba(255, 255, 255, 0.6); border: 1px solid rgba(0, 0, 0, 0.05); color: #B0B0B0; font-weight: 600;', '#B0B0B0', il, ir)
    nav = lambda l, a: ('<span style="font-size: 15px; font-weight: 600; color: ' + INK + ';">' + l + '</span>' if a
                        else '<span style="font-size: 15px; font-weight: 500; color: rgba(31, 31, 31, 0.78);">' + l + '</span>')
    band = ('<div style="background: linear-gradient(120deg, #FFD9BF 0%, #FFF0B3 55%, #FFFFFF 100%); padding-bottom: 96px;">'
            '<div style="height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
            '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-size: 20px; font-weight: 700; letter-spacing: -0.02em;">lowpass</span>'
            '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
            '<div style="display: flex; align-items: center; gap: 12px;">' + search_field('rgba(255, 255, 255, 0.85)', '1px solid rgba(0, 0, 0, 0.06)', '999px', MUTED, MUTED) + avatar('#FFFFFF', DEEP) + '</div></div>'
            '<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 48px 64px 0 64px;">'
            '<div style="display: flex; flex-direction: column; gap: 14px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', '#9A3412') + date_h1(INK, DEEP, 52) + '</div>' + controls(btn, btnd) + '</div></div>\n')
    def chapter(i, title, count, items, mr):
        return ('<section style="display: flex; flex-direction: column; background: #FFFFFF; border: 1px solid #FFF1E6; border-radius: 16px; padding: 28px; box-shadow: 0 12px 32px rgba(249, 115, 22, 0.10);">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 10px;"><h2 style="margin: 0; font-size: 17px; font-weight: 600; color: ' + INK + ';">' + title + '</h2>' + mono(count, META) + '</div>'
                + rows(items, f, '') + '<div style="margin-top: 16px;">' + more(mr, DEEP) + '</div></section>\n')
    grid = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; padding: 0 64px 72px 64px; margin-top: -56px;">' + ''.join(chapter(i, *s) for i, s in enumerate(SOURCES)) + '</div>\n'
    return doc(band + grid, fonts, '#FFFFFF', INK, SANS, css)

# 4 柔和粉彩 --------------------------------------------------------------
def pastel():
    INK, MUTED, META, FIELD = '#2B2B2B', '#5C5C5C', '#666666', '#F6F6F6'
    BLOCKS = [('#FFE3D3', '#9A3412'), ('#FFF4C2', '#854D0E'), ('#D9F5E6', '#065F46')]
    SANS = "'Nunito', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Nunito:wght@400;500;700;800&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = '    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-underline-offset: 3px; }\n'
    btn = lambda l, il, ir: button(l, 'border-radius: 999px; background: ' + FIELD + '; color: ' + INK + '; font-weight: 700;', INK, il, ir)
    btnd = lambda l, il, ir: button(l, 'border-radius: 999px; background: ' + FIELD + '; color: #BDBDBD; font-weight: 700;', '#BDBDBD', il, ir)
    nav = lambda l, a: ('<span style="font-size: 15px; font-weight: 800; color: #9A3412; background: #FFE3D3; border-radius: 999px; padding: 6px 14px;">' + l + '</span>' if a
                        else '<span style="font-size: 15px; font-weight: 700; color: ' + MUTED + '; padding: 6px 14px;">' + l + '</span>')
    top = ('<div style="height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
           '<div style="display: flex; align-items: center; gap: 32px;"><span style="font-size: 20px; font-weight: 800;">lowpass</span>'
           '<div style="display: flex; gap: 4px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
           '<div style="display: flex; align-items: center; gap: 12px;">' + search_field(FIELD, 'none', '999px', MUTED, MUTED) + avatar('#D9F5E6', '#047857') + '</div></div>\n')
    head = ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 56px 64px 40px 64px;">'
            '<div style="display: flex; flex-direction: column; gap: 14px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', META) + date_h1(INK, '#C2410C') + '</div>' + controls(btn, btnd) + '</div>\n')
    def chapter(i, title, count, items, mr):
        bg, fg = BLOCKS[i]
        f = dict(title_font=SANS, title_size=16, title_weight=700, title_color=INK, body_font=SANS, summary_color=MUTED, meta_color=META, rank_font=MONO, rank_color=fg, row_pad='10px 0')
        return ('<section style="display: flex; flex-direction: column; background: ' + bg + '; border-radius: 20px; padding: 28px;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 10px;"><h2 style="margin: 0; font-size: 17px; font-weight: 800; color: ' + fg + ';">' + title + '</h2>' + mono(count, fg) + '</div>'
                + rows(items, f, '') + '<div style="margin-top: 16px;">' + more(mr, fg, 800) + '</div></section>\n')
    grid = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; padding: 0 64px 72px 64px;">' + ''.join(chapter(i, *s) for i, s in enumerate(SOURCES)) + '</div>\n'
    return doc(top + head + grid, fonts, '#FFFFFF', INK, SANS, css)

# 5 阳光黄 ----------------------------------------------------------------
def yellow():
    INK, MUTED, META, YEL = '#111111', '#555555', '#6B6B6B', '#FFD23F'
    SANS = "'Sora', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Sora:wght@400;600;700;800&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = ('    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-decoration-color: ' + YEL + '; text-decoration-thickness: 3px; text-underline-offset: 3px; }\n')
    f = dict(title_font=SANS, title_size=16, title_weight=600, title_color=INK, body_font=SANS, summary_color=MUTED, meta_color=META, rank_font=MONO, rank_color=INK, row_pad='12px 0')
    btn = lambda l, il, ir: button(l, 'border-radius: 6px; border: 1.5px solid ' + INK + '; background: transparent; color: ' + INK + '; font-weight: 600;', INK, il, ir)
    btnd = lambda l, il, ir: button(l, 'border-radius: 6px; border: 1.5px solid rgba(17, 17, 17, 0.3); background: transparent; color: rgba(17, 17, 17, 0.4); font-weight: 600;', 'rgba(17, 17, 17, 0.4)', il, ir)
    nav = lambda l, a: ('<span style="font-size: 15px; font-weight: 700; color: ' + INK + '; border-bottom: 3px solid ' + INK + '; padding-bottom: 2px;">' + l + '</span>' if a
                        else '<span style="font-size: 15px; font-weight: 600; color: ' + MUTED + ';">' + l + '</span>')
    top = ('<div style="height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
           '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-size: 20px; font-weight: 800; letter-spacing: -0.03em;">lowpass</span>'
           '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
           '<div style="display: flex; align-items: center; gap: 12px;">' + search_field('#FFFFFF', '1.5px solid ' + INK, '6px', MUTED, INK) + avatar(YEL, INK) + '</div></div>\n')
    head = ('<div style="background: ' + YEL + '; margin: 0 64px; border-radius: 8px; padding: 48px 48px 40px 48px; display: flex; align-items: flex-end; justify-content: space-between;">'
            '<div style="display: flex; flex-direction: column; gap: 14px;">' + mono('日刊 · 2026-09-08 · 06:12 发布', 'rgba(17, 17, 17, 0.7)') + date_h1(INK, 'rgba(17, 17, 17, 0.7)', 56) + '</div>' + controls(btn, btnd) + '</div>\n')
    def chapter(i, title, count, items, mr):
        return ('<section style="display: flex; flex-direction: column;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 6px;"><h2 style="margin: 0; font-size: 18px; font-weight: 800; color: ' + INK + '; background: linear-gradient(transparent 58%, ' + YEL + ' 58%); display: inline; padding: 0 4px;">' + title + '</h2>' + mono(count, META) + '</div>'
                + rows(items, f, ' border-bottom: 1px solid #EAEAEA;') + '<div style="margin-top: 16px;">' + more(mr, INK, 700, ' text-decoration: underline; text-decoration-color: ' + YEL + '; text-decoration-thickness: 3px; text-underline-offset: 4px;') + '</div></section>\n')
    grid = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 48px; padding: 48px 64px 72px 64px;">' + ''.join(chapter(i, *s) for i, s in enumerate(SOURCES)) + '</div>\n'
    return doc(top + head + grid, fonts, '#FFFFFF', INK, SANS, css)

# 6 清新绿 ----------------------------------------------------------------
def green():
    INK, MUTED, META, GREEN, DEEP, DEEPER, LEAF, LINE, SUN = '#1B2B22', '#4B5B50', '#5E6E63', '#16A34A', '#15803D', '#166534', '#E8F5EC', '#EEF4F0', '#F5C518'
    SANS = "'Figtree', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
    fonts = 'https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;700&display=swap'
    css = '    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + DEEP + '; text-decoration: underline; text-underline-offset: 3px; }\n'
    f = dict(title_font=SANS, title_size=16, title_weight=500, title_color=INK, body_font=SANS, summary_color=MUTED, meta_color=META, rank_font=MONO, rank_color=DEEP, row_pad='11px 0')
    btn = lambda l, il, ir: button(l, 'border-radius: 10px; border: 1px solid #DCEFE2; background: #FFFFFF; color: ' + INK + '; font-weight: 600;', INK, il, ir)
    btnd = lambda l, il, ir: button(l, 'border-radius: 10px; border: 1px solid ' + LINE + '; background: #FFFFFF; color: #A7B3AB; font-weight: 600;', '#A7B3AB', il, ir)
    nav = lambda l, a: ('<span style="font-size: 15px; font-weight: 600; color: ' + INK + '; border-bottom: 2px solid ' + GREEN + '; padding-bottom: 3px;">' + l + '</span>' if a
                        else '<span style="font-size: 15px; font-weight: 500; color: ' + MUTED + ';">' + l + '</span>')
    top = ('<div style="height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">'
           '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-size: 18px; font-weight: 700; color: ' + DEEP + '; letter-spacing: -0.02em;">lowpass</span>'
           '<div style="display: flex; gap: 28px;">' + nav('日刊', True) + nav('周刊', False) + nav('搜索', False) + '</div></div>'
           '<div style="display: flex; align-items: center; gap: 12px;">' + search_field('#FFFFFF', '1px solid #DCEFE2', '10px', MUTED, MUTED) + avatar(LEAF, DEEP) + '</div></div>\n')
    head = ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 56px 64px 40px 64px;">'
            '<div style="display: flex; flex-direction: column; gap: 14px;"><div style="display: flex; align-items: center; gap: 10px;"><span style="width: 12px; height: 12px; border-radius: 50%; background: ' + SUN + '; display: inline-block;"></span>' + mono('日刊 · 2026-09-08 · 06:12 发布', META) + '</div>'
            + date_h1(INK, DEEP) + '</div>' + controls(btn, btnd) + '</div>\n')
    def chapter(i, title, count, items, mr):
        return ('<section style="display: flex; flex-direction: column;">'
                '<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;"><h2 style="margin: 0; font-size: 14px; font-weight: 700; color: ' + DEEPER + '; background: ' + LEAF + '; border-radius: 999px; padding: 6px 14px;">' + title + '</h2>' + mono(count, META) + '</div>'
                + rows(items, f, ' border-bottom: 1px solid ' + LINE + ';') + '<div style="margin-top: 16px;">' + more(mr, DEEP) + '</div></section>\n')
    grid = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 48px; padding: 0 64px 72px 64px;">' + ''.join(chapter(i, *s) for i, s in enumerate(SOURCES)) + '</div>\n'
    return doc(top + head + grid, fonts, '#FFFFFF', INK, SANS, css)
