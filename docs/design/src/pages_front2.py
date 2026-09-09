"""第八轮：纵向有重心的纸报。每源一节，节内头条放大做重心，右侧 2 到 10 条紧凑列表。四个字体家族。"""
import re
from common import *
from pages_warm import doc
from pages_press import HN30, GH25, HAD12, ill_bubbles, ill_branches, ill_solder, ill_sunrise

GROUND, PAPER, INK, INK2, GREEN = '#26241F', '#E8E3DA', '#1D1D1B', '#55504B', '#96B59F'
RULE = 'rgba(29, 29, 27, 0.35)'
UL = 'rgba(29, 29, 27, 0.30)'
# 字体方案 A（2026-09-09 定稿）：一个角色一个家族。品牌 Bodoni 只用于报头与邮戳；拉丁内容 Newsreader；所有中文霞鹜文楷；数据 Maple Mono。
NAME = "'Bodoni Moda', 'LXGW WenKai Screen', serif"
SERIF = "'Newsreader', 'LXGW WenKai Screen', 'Songti SC', serif"
KAIF = "'LXGW WenKai Screen', 'Songti SC', 'STSong', serif"
MONOF = "'Maple Mono NL', ui-monospace, Menlo, monospace"
FONTS = 'https://fonts.googleapis.com/css2?family=Bodoni+Moda:opsz,wght@6..96,400..900&family=Newsreader:ital,opsz,wght@0,6..72,400..700;1,6..72,400..700&display=swap'

def css():
    return ('    a { color: ' + INK + '; text-decoration: none; }\n'
            '    a.t { text-decoration: underline; text-decoration-color: ' + UL + '; text-decoration-thickness: 1px; text-underline-offset: 4px; }\n'
            '    a.t:hover, a:hover { color: ' + INK + '; text-decoration: underline; text-decoration-color: ' + INK + '; text-decoration-thickness: 1px; text-underline-offset: 4px; }\n')

CJK = re.compile(r'([\u2E80-\u9FFF\uFF00-\uFFEF]+)')

def mixed(text, color=INK2, size=13, latin_extra=''):
    """等宽字里夹中文：中文词段改用正文衬线，同字号同色，避免回退字体的粗细不一。"""
    out = []
    for run in CJK.split(text):
        if not run:
            continue
        if CJK.fullmatch(run):
            out.append('<span style="font-family: ' + KAIF + '; font-size: ' + str(size) + 'px; color: ' + color + ';">' + run + '</span>')
        else:
            out.append('<span style="font-family: ' + MONOF + '; font-size: ' + str(size) + 'px; color: ' + color + ';' + latin_extra + '">' + run + '</span>')
    return ''.join(out)

def mono2(text, color=INK2, size=13):
    return '<span style="white-space: nowrap;">' + mixed(text, color, size) + '</span>'

def label(text, color=INK2, size=12):
    """小标：纯拉丁时等宽大写加字距；夹中文时不做大写变换，中文字段用衬线。"""
    extra = ' text-transform: uppercase; letter-spacing: 0.12em;' if not CJK.search(text) else ''
    return '<span style="white-space: nowrap;">' + mixed(text, color, size, extra) + '</span>'

def mm(parts, color=INK2, size=13):
    """元数据：数字与符号用等宽，中文词用正文衬线，同一行同一色。"""
    out = []
    for text, kind in parts:
        fam = MONOF if kind == 'm' else KAIF
        out.append('<span style="font-family: ' + fam + '; font-size: ' + str(size) + 'px; color: ' + color + ';">' + text + '</span>')
    return '<span style="display: inline-flex; align-items: baseline; gap: 6px; flex-wrap: wrap;">' + ''.join(out) + '</span>'

def hn_meta(m):
    """HN 元数据只用数字与记号：▲ 分数 · 对话框图标 评论数 · 相对时间。"""
    score, comments, age = [x.strip() for x in m.split('·')]
    n = comments.split(' ')[0]
    dot = mono2('·')
    return ('<span style="display: inline-flex; align-items: center; gap: 6px; white-space: nowrap;">' + mono2(score) + dot
            + '<span style="display: inline-flex; align-items: center; gap: 4px;">' + icon('message-square', 12, INK2) + mono2(n) + '</span>' + dot + mono2(age) + '</span>')

def badge(text):
    return '<span style="font-family: ' + MONOF + '; font-size: 12px; background: ' + GREEN + '; color: ' + INK + '; padding: 2px 7px; border-radius: 2px; white-space: nowrap;">' + text + '</span>'

def icon_svg(inner, size=44):
    return ('<svg viewBox="0 0 120 78" width="' + str(round(size * 120 / 78)) + '" height="' + str(size) + '" fill="none" stroke="' + INK + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex: none; display: block;">' + inner + '</svg>')

def ctrl(l, il=None, ir=None, off=False, h=40):
    col = INK2 if off else INK
    return ('<span style="display: inline-flex; align-items: center; gap: 6px; height: ' + str(h) + 'px; padding: 0 14px; border: 1px solid ' + (RULE if off else INK) + '; font-family: ' + KAIF + '; font-size: 15px; color: ' + col + '; white-space: nowrap;">'
            + (icon(il, 14, col) if il else '') + '<span>' + l + '</span>' + (icon(ir, 14, col) if ir else '') + '</span>')

def masthead(active='日刊', compact=False):
    h = 56 if compact else 80
    size = 26 if compact else 40
    def nav(l):
        st = 'font-family: ' + KAIF + '; font-size: 15px; color: ' + PAPER + ';'
        if l == active:
            st += ' border-bottom: 1px solid ' + PAPER + '; padding-bottom: 2px;'
        else:
            st += ' opacity: 0.72;'
        return '<span style="' + st + '">' + l + '</span>'
    right = (icon('menu', 22, PAPER) if compact else
             '<div style="display: flex; align-items: center; gap: 22px;">' + icon('search', 20, PAPER) + '<span style="width: 32px; height: 32px; border-radius: 50%; border: 1px solid ' + PAPER + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 15, PAPER) + '</span></div>')
    navs = '' if compact else '<div style="display: flex; gap: 26px;">' + nav('日刊') + nav('周刊') + nav('搜索') + '</div>'
    return ('<div style="height: ' + str(h) + 'px; background: ' + INK + '; display: flex; align-items: center; justify-content: space-between; padding: 0 ' + ('20px' if compact else '40px') + ';">'
            '<div style="display: flex; align-items: center; gap: 40px;"><span style="font-family: ' + NAME + '; font-size: ' + str(size) + 'px; font-weight: 900; letter-spacing: 0.02em; text-transform: uppercase; color: ' + PAPER + '; line-height: 1;">lowpass</span>' + navs + '</div>'
            + right + '</div>')

def issue_head(status=None, compact=False):
    date_size, wk_size = (40, 15) if compact else (56, 20)
    controls = ('' if compact else '<div style="display: flex; gap: 8px; align-items: center;">' + ctrl('9月7日', il='chevron-left') + ctrl('归档') + ctrl('9月9日', ir='chevron-right', off=True) + '</div>')
    tag = ('<span style="display: inline-flex; align-items: center; gap: 6px; border: 1px solid ' + INK + '; padding: 3px 8px;">' + icon('clock', 13, INK) + mono2(status, INK, 12) + '</span>' if status else '')
    return ('<div style="display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; padding: ' + ('24px 0 16px 0' if compact else '32px 0 20px 0') + '; border-bottom: 2px solid ' + INK + ';">'
            '<div style="display: flex; flex-direction: column; gap: 10px;"><span style="font-family: ' + KAI + '; font-size: ' + str(date_size) + 'px; line-height: 1;">9月8日 <span style="font-size: ' + str(wk_size) + 'px; color: ' + INK2 + ';">星期二</span></span>'
            '<div style="display: flex; align-items: center; gap: 12px;">' + mono2('06:12 发布') + tag + '</div></div>' + controls + '</div>')

def section_head(title, kicker_text, ill, compact=False):
    return ('<div style="display: flex; align-items: center; gap: 16px; padding: ' + ('28px 0 12px 0' if compact else '40px 0 14px 0') + ';">' + icon_svg(ill, 36 if compact else 44)
            + '<div style="display: flex; flex-direction: column; gap: 4px;"><h2 style="margin: 0; font-family: ' + NAME + '; font-size: ' + ('26px' if compact else '32px') + '; font-weight: 700; line-height: 1.05;">' + title + '</h2>' + label(kicker_text) + '</div></div>'
            '<div style="height: 1px; background: ' + INK + ';"></div>')

def lead(rank, title, meta_html, secondary=None, compact=False):
    """头条：桌面版横贯整节，序号在左；手机版纵向堆叠。"""
    if compact:
        return ('<div style="display: flex; flex-direction: column; gap: 12px; padding: 16px 0 14px 0; border-bottom: 1px solid ' + RULE + ';">'
                '<span style="font-family: ' + NAME + '; font-size: 28px; font-weight: 700; line-height: 1; color: ' + INK2 + ';">' + rank.lstrip('0') + '</span>'
                '<a href="#" class="t" style="font-family: ' + SERIF + '; font-size: 24px; line-height: 1.25; font-weight: 500;">' + title + '</a>'
                + ('<span style="font-size: 16px; line-height: 1.5; color: ' + INK2 + ';">' + secondary + '</span>' if secondary else '')
                + meta_html + '</div>')
    return ('<div style="display: grid; grid-template-columns: 56px minmax(0, 1fr); gap: 20px; padding: 24px 0 22px 0; border-bottom: 1px solid ' + RULE + ';">'
            '<span style="font-family: ' + NAME + '; font-size: 44px; font-weight: 700; line-height: 1; color: ' + INK2 + '; padding-top: 2px;">' + rank.lstrip('0') + '</span>'
            '<div style="display: flex; flex-direction: column; gap: 12px; max-width: 880px;">'
            '<a href="#" class="t" style="font-family: ' + SERIF + '; font-size: 30px; line-height: 1.25; font-weight: 500;">' + title + '</a>'
            + ('<span style="font-size: 17px; line-height: 1.5; color: ' + INK2 + ';">' + secondary + '</span>' if secondary else '')
            + meta_html + '</div></div>')

def row(rank, title, meta_html, secondary=None):
    return ('<div style="display: grid; grid-template-columns: 28px minmax(0, 1fr); gap: 12px; padding: 12px 0; border-bottom: 1px solid ' + RULE + ';">'
            + '<span style="padding-top: 3px; font-family: ' + MONOF + '; font-size: 13px; color: ' + INK2 + ';">' + rank.lstrip('0') + '</span>'
            + '<div style="display: flex; flex-direction: column; gap: 5px; min-width: 0;"><a href="#" class="t" style="font-size: 17px; line-height: 1.35; font-weight: 500;">' + title + '</a>'
            + ('<span style="font-size: 14.5px; line-height: 1.45; color: ' + INK2 + '; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;">' + secondary + '</span>' if secondary else '')
            + meta_html + '</div></div>')

def foot_link(text):
    """栏尾外链：拉丁来源名用 Newsreader 500，中文用文楷，箭头图标。"""
    parts = []
    for run in CJK.split(text):
        if not run:
            continue
        if CJK.fullmatch(run):
            parts.append('<span style="font-family: ' + KAIF + '; font-size: 15px; color: ' + INK + ';">' + run + '</span>')
        else:
            parts.append('<span style="font-family: ' + SERIF + '; font-size: 15px; font-weight: 500; color: ' + INK + ';">' + run + '</span>')
    return '<a href="#" style="display: inline-flex; align-items: center; gap: 6px; padding-top: 14px;">' + ''.join(parts) + icon('arrow-up-right', 13, INK) + '</a>'

def gh_meta(m, rank):
    lang, stars, delta = [x.strip() for x in m.split('·')]
    parts = [(lang, 'm'), ('·', 'm'), (stars, 'm'), ('·', 'm')]
    tail = badge(delta) if int(rank) <= 3 else mono2(delta)
    return '<span style="display: inline-flex; align-items: center; gap: 6px; flex-wrap: wrap;">' + mm(parts) + tail + '</span>'

def had_meta(m):
    author, age = [x.strip() for x in m.split('·')]
    return mm([(author, 'm'), ('·', 'm'), (age, 'm')])

def section(title, kicker_text, ill, lead_html, rows, foot, compact=False):
    """rows 是第 2 到 10 条的 html 列表。桌面版：头条横贯，其余分两栏（2 到 6 左，7 到 10 右），栏尾外链补在右栏底。"""
    if compact:
        body = '<div style="display: flex; flex-direction: column;">' + lead_html + ''.join(rows) + '</div>' + foot_link(foot)
    else:
        body = (lead_html + '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0 40px;">'
                '<div>' + ''.join(rows[:5]) + '</div>'
                '<div>' + ''.join(rows[5:]) + foot_link(foot) + '</div></div>')
    return '<section>' + section_head(title, kicker_text, ill, compact) + body + '</section>'

def failed_section(title, kicker_text, ill, compact=False):
    box = ('<div style="display: grid; grid-template-columns: 130px minmax(0, 1fr); gap: 24px; align-items: center; padding: 24px 0 8px 0;">'
           '<svg viewBox="0 0 260 138" width="130" height="69" fill="none" stroke="' + INK + '" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" style="display: block; opacity: 0.55;">' + ill_sunrise() + '</svg>'
           '<div style="display: flex; flex-direction: column; gap: 8px;"><span style="font-family: ' + SERIF + '; font-size: 20px; font-weight: 500;">今日抓取失败，已通知管理员</span>'
           + mm([('上次成功', 's'), ('9月7日 06:11', 'm'), ('·', 'm'), ('修复后本栏自动补齐', 's')]) + '</div></div>')
    return '<section>' + section_head(title, kicker_text, ill, compact) + box + foot_link(title + ' 完整榜单') + '</section>'

def empty_section(title, kicker_text, ill, compact=False):
    box = ('<div style="display: flex; flex-direction: column; gap: 6px; padding: 24px 0 8px 0;"><span style="font-family: ' + SERIF + '; font-size: 20px; font-weight: 500;">今日无新内容</span>'
           + mm([('近 24 小时该来源没有新文章', 's'), ('·', 'm'), ('06:12', 'm'), ('检查', 's')]) + '</div>')
    return '<section>' + section_head(title, kicker_text, ill, compact) + box + foot_link(title + ' 全部') + '</section>'

def footer(compact=False):
    stamp = ('<svg viewBox="0 0 64 64" width="48" height="48" fill="none" stroke="' + INK + '" stroke-width="1.6" style="display: block;"><circle cx="32" cy="32" r="29"></circle><circle cx="32" cy="32" r="23" stroke-dasharray="3 3" stroke-width="1"></circle>'
             '<text x="32" y="37" text-anchor="middle" font-family="Bodoni Moda, serif" font-size="15" font-weight="700" fill="' + INK + '" stroke="none">LP</text></svg>')
    return ('<div style="border-top: 2px solid ' + INK + '; margin-top: 36px; padding: 18px 0 8px 0; display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap;">'
            '<div style="display: flex; align-items: center; gap: 16px;">' + stamp + '<div style="display: flex; flex-direction: column; gap: 4px;">' + mono2('明早 06:00 · 下一期') + '<a href="#" class="t" style="font-family: ' + KAIF + '; font-size: 15px;">最新周刊 · 第 36 周 · 阮一峰周刊第 366 期</a></div></div>'
            + ('' if compact else '<div style="display: flex; gap: 8px;">' + ctrl('9月7日', il='chevron-left') + ctrl('归档') + ctrl('9月9日', ir='chevron-right', off=True) + '</div>') + '</div>')

def sheet(inner, width=1240, pad=40, h=2400, margin='32px auto 48px auto'):
    return ('<div style="width: ' + str(width) + 'px; margin: ' + margin + '; box-sizing: border-box; background: ' + PAPER + '; color: ' + INK + '; '
            'background-image: repeating-linear-gradient(0deg, rgba(29, 29, 27, 0.03) 0 1px, transparent 1px 3px), repeating-linear-gradient(90deg, rgba(255, 255, 255, 0.14) 0 1px, transparent 1px 4px); box-shadow: 0 30px 80px rgba(0, 0, 0, 0.45);">'
            + inner + '</div>\n')

def hn_section(compact=False, failed=False):
    if failed:
        return failed_section('Hacker News', '前 10 条 · 榜单顺序', ill_bubbles(), compact)
    r1 = HN30[0]
    ld = lead(r1[0], r1[1], hn_meta(r1[2]), None, compact)
    rows = [row(r, t, hn_meta(m)) for r, t, m in HN30[1:10]]
    return section('Hacker News', '前 10 条 · 榜单顺序', ill_bubbles(), ld, rows, 'Hacker News 完整榜单', compact)

def gh_section(compact=False, empty=False):
    if empty:
        return empty_section('GitHub Trending', '今日前 10 · 新增 star 降序', ill_branches(), compact)
    r1 = GH25[0]
    ld = lead(r1[0], r1[1], gh_meta(r1[2], r1[0]), r1[3], compact)
    rows = [row(r, n, gh_meta(m, r), d) for r, n, m, d in GH25[1:10]]
    return section('GitHub Trending', '今日前 10 · 新增 star 降序', ill_branches(), ld, rows, 'GitHub Trending 完整榜单', compact)

def had_section(compact=False):
    r1 = HAD12[0]
    ld = lead(r1[0], r1[1], had_meta(r1[2]), r1[3], compact)
    rows = [row(r, t, had_meta(m), s) for r, t, m, s in HAD12[1:10]]
    return section('Hackaday', '近 24 小时最新 10 篇', ill_solder(), ld, rows, 'Hackaday 完整列表', compact)

def front2():
    inner = masthead() + '<div style="padding: 0 40px 28px 40px;">' + issue_head() + hn_section() + gh_section() + had_section() + footer() + '</div>'
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 2700)

def front2_states():
    inner = masthead() + '<div style="padding: 0 40px 28px 40px;">' + issue_head(status='延迟生成于 07:05') + hn_section(failed=True) + gh_section(empty=True) + had_section() + footer() + '</div>'
    return doc(sheet(inner), FONTS, GROUND, INK, SERIF, css(), 1850)

def front2_mobile():
    inner = (masthead(compact=True) + '<div style="padding: 0 20px 24px 20px;">' + issue_head(compact=True)
             + '<div style="display: flex; gap: 8px; padding: 14px 0 0 0;">' + ctrl('9月7日', il='chevron-left', h=44) + ctrl('归档', h=44) + ctrl('9月9日', ir='chevron-right', off=True, h=44) + '</div>'
             + hn_section(compact=True) + gh_section(compact=True) + had_section(compact=True) + footer(compact=True) + '</div>')
    return doc(sheet(inner, width=390, margin='0'), FONTS, PAPER, INK, SERIF, css(), 4400)
