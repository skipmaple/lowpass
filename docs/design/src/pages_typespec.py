"""字体审核样张：同一组内容在 现状 / 方案 A / 方案 B 三种字体方案下的对照，附方案 A 的字号阶梯。"""
import re
from common import *
from pages_warm import doc
from pages_press import ill_bubbles, ill_solder
from pages_front2 import GROUND, PAPER, INK, INK2, GREEN, RULE, NAME, MONOF, FONTS, css, badge, sheet

CJK_RE = re.compile(r'([⺀-鿿＀-￯]+)')
KAIF = "'LXGW WenKai Screen', 'Noto Serif SC', 'Songti SC', serif"
NOTOF = "'Noto Serif SC', 'Songti SC', serif"
NEWSF = "'Newsreader', 'Noto Serif SC', 'Songti SC', serif"
PAPER_DIM = 'rgba(232, 227, 218, 0.72)'

SCHEMES = [
    dict(key='now', title='现状', families='Bodoni Moda · Newsreader · Noto Serif SC（回退）· 霞鹜文楷 · Maple Mono',
         cjk=NOTOF, ui=NEWSF, week=NEWSF, tab=NAME, tab_size=24, tab_weight=700, reason_size=15, reason_lh=1.55, ui_size=15),
    dict(key='A', title='方案 A · 推荐：中文全部文楷', families='Bodoni Moda（仅报头）· Newsreader · 霞鹜文楷 · Maple Mono',
         cjk=KAIF, ui=KAIF, week=KAIF, tab=NEWSF, tab_size=22, tab_weight=600, reason_size=15, reason_lh=1.7, ui_size=15),
    dict(key='B', title='方案 B · 备选：中文用 Noto Serif SC', families='Bodoni Moda（仅报头）· Newsreader · Noto Serif SC · 霞鹜文楷（仅日期）· Maple Mono',
         cjk=NOTOF, ui=NOTOF, week=NOTOF, tab=NEWSF, tab_size=22, tab_weight=600, reason_size=14, reason_lh=1.65, ui_size=14),
]

def span(text, fam, size, color=INK, extra=''):
    return '<span style="font-family: ' + fam + '; font-size: ' + str(size) + 'px; color: ' + color + ';' + extra + '">' + text + '</span>'

def mix(text, cjk, size, color=INK2):
    out = []
    for run in CJK_RE.split(text):
        if not run:
            continue
        out.append(span(run, cjk if CJK_RE.fullmatch(run) else MONOF, size, color))
    return '<span style="white-space: nowrap;">' + ''.join(out) + '</span>'

def isvg(inner, size, color):
    return ('<svg viewBox="0 0 120 78" width="' + str(round(size * 120 / 78)) + '" height="' + str(size) + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex: none; display: block;">' + inner + '</svg>')

def tabs(s):
    def tab(name, ill, on, first):
        fg = PAPER if on else INK
        st = ('flex: 0 0 auto; display: flex; align-items: center; gap: 10px; padding: 10px 14px; border: 1px solid ' + INK + '; min-width: 0;'
              + (' background: ' + INK + ';' if on else '') + ('' if first else ' margin-left: -1px;'))
        inner = ill().replace(PAPER, INK) if on else ill()
        return ('<span style="' + st + '">' + isvg(inner, 26, fg) + '<span style="font-family: ' + s['tab'] + '; font-size: ' + str(s['tab_size']) + 'px; font-weight: ' + str(s['tab_weight']) + '; line-height: 1; color: ' + fg + '; white-space: nowrap;">' + name + '</span></span>')
    return '<div style="display: flex; margin-top: 18px;">' + tab('Hacker News', ill_bubbles, True, True) + tab('Hackaday', ill_solder, False, False) + '</div>'

def item(s, rank, title, meta_html, tag, reason, secondary=None):
    chip = '<span style="display: inline-flex; align-items: center; height: 24px; padding: 0 8px; border: 1px solid ' + RULE + '; white-space: nowrap;">' + span(tag, s['cjk'], 12, INK2) + '</span>'
    sec = ('<span style="font-family: ' + NEWSF + '; font-size: 15px; line-height: 1.5; color: ' + INK2 + ';">' + secondary + '</span>') if secondary else ''
    reason_html = ('<div style="border-left: 2px solid ' + GREEN + '; padding: 1px 0 1px 12px; margin-top: 4px; font-family: ' + s['cjk'] + '; font-size: ' + str(s['reason_size']) + 'px; line-height: ' + str(s['reason_lh']) + '; color: ' + INK2 + ';">' + reason + '</div>')
    return ('<div style="display: grid; grid-template-columns: 28px minmax(0, 1fr); gap: 12px; padding: 16px 0; border-bottom: 1px solid ' + RULE + ';">'
            + span(rank, MONOF, 13, INK2, ' padding-top: 5px;')
            + '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0;"><a href="#" class="t" style="font-family: ' + NEWSF + '; font-size: 20px; line-height: 1.35; font-weight: 500;">' + title + '</a>' + sec
            + '<span style="display: inline-flex; align-items: center; gap: 10px; flex-wrap: wrap;">' + meta_html + chip + '</span>' + reason_html + '</div></div>')

def column(s):
    head = ('<div style="display: flex; flex-direction: column; gap: 6px; padding-bottom: 14px; border-bottom: 1px solid ' + INK + ';">'
            + span(s['title'], KAIF, 16, INK) + span(s['families'], MONOF if False else KAIF, 12, INK2) + '</div>')
    date = ('<div style="display: flex; flex-direction: column; gap: 8px; padding: 22px 0 14px 0; border-bottom: 2px solid ' + INK + ';">'
            '<span style="font-family: ' + KAI + '; font-size: 44px; line-height: 1;">9月8日 ' + span('星期二', s['week'], 18, INK2) + '</span>'
            + mix('06:12 发布', s['cjk'], 13) + '</div>')
    gh_meta = '<span style="display: inline-flex; align-items: center; gap: 6px;">' + mix('Zig · ★ 12.3k ·', s['cjk'], 13) + badge('+420') + '</span>'
    items = (item(s, '1', 'Show HN: A terminal log viewer written in Rust', mix('▲ 312 · 145 评论 · 5h', s['cjk'], 13), '开发者效率',
                  '命中开发工具偏好：Rust 写的终端日志查看器，大文件过滤与高亮的做法可直接用在日常排障。')
             + item(s, '2', 'acme/lowlatency-db', gh_meta, '嵌入式', '嵌入式与后端架构交集：占用极小的时序数据库，适合传感器数据在设备端落盘。',
                    'An embedded time-series database with a tiny footprint'))
    def btn(l, off=False):
        col = INK2 if off else INK
        return '<span style="display: inline-flex; align-items: center; height: 40px; padding: 0 14px; border: 1px solid ' + (RULE if off else INK) + ';">' + span(l, s['ui'], s['ui_size'], col) + '</span>'
    buttons = '<div style="display: flex; gap: 8px; padding-top: 18px;">' + btn('‹ 9月7日') + btn('归档') + btn('9月9日 ›', True) + '</div>'
    state = '<div style="padding-top: 16px;">' + span('今日抓取失败，已通知管理员', s['cjk'], 18, INK) + '<div style="padding-top: 6px;">' + mix('上次成功 9月7日 06:11 · 修复后本栏自动补齐', s['cjk'], 13) + '</div></div>'
    return '<div style="min-width: 0;">' + head + date + tabs(s) + '<div style="border-top: 1px solid ' + INK + '; margin-top: 18px;">' + items + '</div>' + buttons + state + '</div>'

def scale_table():
    rows = [
        ('品牌', 'Bodoni Moda 900', '报头 LOWPASS、LP 邮戳', '40 桌面 · 26 手机'),
        ('内容（拉丁）', 'Newsreader 400 / 500 / 600', '条目标题、简介、摘要、索引条来源名', '20/500/1.35 · 15/400/1.5 · 22/600'),
        ('中文', '霞鹜文楷 Screen', '日期、星期、导航、按钮、标签、推荐理由、状态、元数据中的中文单位', '56 · 20 · 15 · 15/1.7 · 12'),
        ('数据', 'Maple Mono NL 400', '序号、分数、评论数、时间、star、今日新增、语言名、发布时间', '13 · 小标 12 大写加字距'),
    ]
    cell = lambda t, fam=KAIF, size=14, color=INK: '<td style="padding: 10px 14px 10px 0; border-bottom: 1px solid ' + RULE + '; vertical-align: top;">' + span(t, fam, size, color) + '</td>'
    head = ''.join('<th style="text-align: left; padding: 0 14px 10px 0; border-bottom: 1px solid ' + INK + ';">' + span(h, KAIF, 12, INK2) + '</th>' for h in ['角色', '家族与字重', '用途', '字号 / 字重 / 行高'])
    body = ''.join('<tr>' + cell(a) + cell(b, MONOF, 13) + cell(c, KAIF, 14, INK2) + cell(d, MONOF, 13, INK2) + '</tr>' for a, b, c, d in rows)
    return ('<div style="margin-top: 48px; border-top: 2px solid ' + INK + '; padding-top: 18px;">' + span('方案 A 的字号阶梯：12 · 13 · 15 · 20 · 22 · 26 · 40 · 56，八档；页面上所有中文只用文楷，所有数字只用 Maple。', KAIF, 15, INK)
            + '<table style="border-collapse: collapse; width: 100%; margin-top: 14px;"><thead><tr>' + head + '</tr></thead><tbody>' + body + '</tbody></table></div>')

def typespec():
    cols = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0 40px;">' + ''.join(column(s) for s in SCHEMES) + '</div>'
    inner = '<div style="padding: 40px;">' + span('字体审核样张 · 2026-09-09', KAIF, 13, INK2) + '<div style="height: 18px;"></div>' + cols + scale_table() + '</div>'
    return doc(sheet(inner, width=1360), FONTS, GROUND, INK, NEWSF, css(), 1500)
