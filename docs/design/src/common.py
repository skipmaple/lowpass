# 共用片段：设计令牌、字体、图标、顶栏、期头、列表行。所有画板从这里拼装。
import base64, os

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.join(HERE, '..', 'fonts')

INK = '#000000'
INK64 = 'rgba(0, 0, 0, 0.64)'
INK56 = 'rgba(0, 0, 0, 0.56)'
INK44 = 'rgba(0, 0, 0, 0.44)'
BORDER = 'rgba(0, 0, 0, 0.10)'
BORDER_STRONG = 'rgba(0, 0, 0, 0.18)'
HOVER = 'rgba(0, 0, 0, 0.05)'
PRESSED = 'rgba(0, 0, 0, 0.09)'
ALT = 'rgba(0, 0, 0, 0.03)'
WARN = '#8A5A00'

SANS = "'Inter', 'Noto Sans SC', 'PingFang SC', 'Hiragino Sans GB', system-ui, sans-serif"
KAI = "'LXGW WenKai Screen', 'Songti SC', 'STSong', serif"
MONO = "'Maple Mono NL', ui-monospace, Menlo, monospace"

def font_css():
    def b64(name):
        with open(os.path.join(FONT_DIR, name), 'rb') as f:
            return base64.b64encode(f.read()).decode()
    return (
        "@font-face { font-family: 'LXGW WenKai Screen'; src: url(data:font/woff2;base64," + b64('wenkai-sub.woff2') +
        ") format('woff2'); font-weight: 400; font-style: normal; font-display: swap; }\n"
        "@font-face { font-family: 'Maple Mono NL'; src: url(data:font/woff2;base64," + b64('maple-sub.woff2') +
        ") format('woff2'); font-weight: 400; font-style: normal; font-display: swap; }\n"
    )

def document(body, width, min_height):
    """包成 Design Component 文档。"""
    helmet = (
        "<helmet>\n"
        "  <link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Noto+Sans+SC:wght@400;500&display=swap\">\n"
        "  <style>\n" + font_css() +
        "    body { margin: 0; }\n"
        "    a { color: #000000; text-decoration: none; }\n"
        "    a:hover { color: #000000; text-decoration: underline; text-underline-offset: 3px; }\n"
        "    mark { background: rgba(0, 0, 0, 0.09); color: inherit; padding: 0 2px; border-radius: 2px; }\n"
        "  </style>\n"
        "</helmet>\n"
    )
    root_open = (
        '<div style="width: ' + str(width) + 'px; min-height: ' + str(min_height) + 'px; box-sizing: border-box; '
        'background: #FFFFFF; color: #000000; font-family: ' + SANS + '; font-size: 16px; line-height: 1.6;">\n'
    )
    return (
        "<!doctype html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <script src=\"./support.js\"></script>\n</head>\n<body>\n<x-dc>\n"
        + helmet + root_open + body + "</div>\n</x-dc>\n</body>\n</html>\n"
    )

# Lucide 图标（24 网格，描边）。morphicons 在实现中负责这些图标之间的形变过渡。
ICON_PATHS = {
    'search': '<circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.3-4.3"></path>',
    'chevron-left': '<path d="m15 18-6-6 6-6"></path>',
    'chevron-right': '<path d="m9 18 6-6-6-6"></path>',
    'chevron-down': '<path d="m6 9 6 6 6-6"></path>',
    'arrow-right': '<path d="M5 12h14"></path><path d="m12 5 7 7-7 7"></path>',
    'arrow-up-right': '<path d="M7 7h10v10"></path><path d="M7 17 17 7"></path>',
    'calendar': '<path d="M8 2v4"></path><path d="M16 2v4"></path><rect width="18" height="18" x="3" y="4" rx="2"></rect><path d="M3 10h18"></path>',
    'book-open': '<path d="M12 7v14"></path><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"></path>',
    'user': '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle>',
    'check': '<path d="M20 6 9 17l-5-5"></path>',
    'triangle-alert': '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"></path><path d="M12 9v4"></path><path d="M12 17h.01"></path>',
    'refresh-cw': '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"></path><path d="M21 3v5h-5"></path><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"></path><path d="M8 16H3v5"></path>',
    'menu': '<path d="M4 12h16"></path><path d="M4 6h16"></path><path d="M4 18h16"></path>',
    'x': '<path d="M18 6 6 18"></path><path d="m6 6 12 12"></path>',
    'archive': '<rect width="20" height="5" x="2" y="3" rx="1"></rect><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"></path><path d="M10 12h4"></path>',
    'clock': '<circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline>',
    'log-out': '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path><polyline points="16 17 21 12 16 7"></polyline><line x1="21" x2="9" y1="12" y2="12"></line>',
    'settings': '<circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path>',
    'shield': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"></path>',
}

def icon(name, size=20, color=INK64, stroke=1.75):
    return ('<svg width="' + str(size) + '" height="' + str(size) + '" viewBox="0 0 24 24" fill="none" stroke="' + color +
            '" stroke-width="' + str(stroke) + '" stroke-linecap="round" stroke-linejoin="round" style="flex: none;">' + ICON_PATHS[name] + '</svg>')

def label(text, color=INK44, size=13):
    """无衬线小标签：眉题、图例、说明句。"""
    return '<span style="font-size: ' + str(size) + 'px; color: ' + color + ';">' + text + '</span>'

def mono(text, color=INK56, size=13):
    return '<span style="font-family: ' + MONO + '; font-size: ' + str(size) + 'px; color: ' + color + ';">' + text + '</span>'

def topbar(active='日刊', width=1440):
    """桌面顶栏：字标、导航、搜索框、头像。"""
    def nav(label):
        if label == active:
            return '<span style="font-size: 15px; font-weight: 500; color: #000000;">' + label + '</span>'
        return '<span style="font-size: 15px; color: ' + INK64 + ';">' + label + '</span>'
    return (
        '<div style="height: 64px; display: flex; align-items: center; justify-content: space-between; padding: 0 64px;">\n'
        '  <div style="display: flex; align-items: center; gap: 40px;">\n'
        '    <span style="font-size: 16px; font-weight: 500;">lowpass</span>\n'
        '    <div style="display: flex; gap: 28px;">' + nav('日刊') + nav('周刊') + nav('搜索') + '</div>\n'
        '  </div>\n'
        '  <div style="display: flex; align-items: center; gap: 12px;">\n'
        '    <div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 12px; border: 1px solid ' + BORDER_STRONG + '; border-radius: 8px; box-sizing: border-box; color: ' + INK44 + '; font-size: 14px;">' + icon('search', 18, INK44) + '<span>搜标题、摘要或来源</span></div>\n'
        '    <span style="width: 36px; height: 36px; border-radius: 50%; background: ' + PRESSED + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 18, INK64) + '</span>\n'
        '  </div>\n'
        '</div>\n'
    )

def topbar_mobile():
    return (
        '<div style="height: 56px; display: flex; align-items: center; justify-content: space-between; padding: 0 24px;">\n'
        '  <span style="font-size: 16px; font-weight: 500;">lowpass</span>\n'
        '  <div style="display: flex; align-items: center; gap: 20px;">' + icon('search', 22, INK64) + icon('menu', 22, INK64) + '</div>\n'
        '</div>\n'
    )

def button(label, kind='outline', icon_left=None, icon_right=None, height=40, disabled=False):
    base = 'display: inline-flex; align-items: center; gap: 8px; height: ' + str(height) + 'px; padding: 0 14px; border-radius: 8px; font-size: 14px; font-weight: 500; box-sizing: border-box; white-space: nowrap;'
    fg = INK44 if disabled else INK
    if kind == 'primary':
        style = base + ' background: #000000; color: #FFFFFF; border: 1px solid #000000;'
    elif kind == 'ghost':
        style = base + ' color: ' + fg + '; border: 1px solid transparent;'
    else:
        style = base + ' color: ' + fg + '; border: 1px solid ' + (BORDER if disabled else BORDER_STRONG) + '; background: #FFFFFF;'
    ic_color = '#FFFFFF' if kind == 'primary' else (INK44 if disabled else INK)
    left = icon(icon_left, 16, ic_color) if icon_left else ''
    right = icon(icon_right, 16, ic_color) if icon_right else ''
    return '<span style="' + style + '">' + left + '<span>' + label + '</span>' + right + '</span>'

def issue_header(label, title, subtitle, controls, kai_size=44, padding='56px 64px 40px 64px'):
    """期头：等宽小标、文楷大标、右侧导航。"""
    return (
        '<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: ' + padding + ';">\n'
        '  <div style="display: flex; flex-direction: column; gap: 12px;">\n'
        '    ' + mono(label) + '\n'
        '    <h1 style="margin: 0; font-family: ' + KAI + '; font-weight: 400; font-size: ' + str(kai_size) + 'px; line-height: 1.1; display: flex; align-items: baseline; gap: 16px;">'
        '<span>' + title + '</span>' + ('<span style="font-size: ' + str(round(kai_size / 2)) + 'px; color: ' + INK64 + ';">' + subtitle + '</span>' if subtitle else '') + '</h1>\n'
        '  </div>\n'
        '  <div style="display: flex; gap: 8px; align-items: center;">' + controls + '</div>\n'
        '</div>\n'
    )

def chapter_head(title, count):
    return ('<div style="display: flex; justify-content: space-between; align-items: baseline;">'
            '<h2 style="margin: 0; font-size: 18px; font-weight: 500; line-height: 1.3;">' + title + '</h2>' + mono(count) + '</div>\n')

def row(rank, title, meta, summary=None, rank_width=28):
    parts = ['<a href="#" style="font-size: 16px; line-height: 1.5; color: #000000;">' + title + '</a>']
    if summary:
        parts.append('<span style="font-size: 15px; line-height: 1.5; color: ' + INK64 + ';">' + summary + '</span>')
    parts.append(mono(meta))
    return (
        '<article style="display: flex; gap: 16px;">'
        + mono(rank, INK44) .replace('<span style="', '<span style="width: ' + str(rank_width) + 'px; flex: none; padding-top: 3px; ')
        + '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0;">' + ''.join(parts) + '</div></article>\n'
    )

def more_link(label):
    return '<a href="#" style="display: inline-flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 500; color: #000000;"><span>' + label + '</span>' + icon('chevron-right', 16, INK) + '</a>\n'

# 样例数据（虚构）。三个日刊源与周刊条目在所有画板里保持一致。
HN = [
    ('01', 'Show HN: A terminal log viewer written in Rust', '▲ 312 · 145 评论 · 5h'),
    ('02', 'Postgres full-text search in production: what we learned', '▲ 287 · 96 评论 · 7h'),
    ('03', 'The case against feature flags', '▲ 201 · 178 评论 · 9h'),
    ('04', 'Ask HN: How do you keep up with tech news without burning out?', '▲ 156 · 233 评论 · 11h'),
    ('05', 'Designing a file format on top of SQLite', '▲ 143 · 41 评论 · 12h'),
    ('06', 'Reverse engineering a $30 smart thermostat', '▲ 120 · 38 评论 · 14h'),
    ('07', 'Kubernetes operators in Rust: a field report', '▲ 98 · 22 评论 · 15h'),
    ('08', 'A gentle introduction to io_uring', '▲ 91 · 17 评论 · 16h'),
]
GH = [
    ('01', 'acme/lowlatency-db', 'Zig · ★ 12.3k · +420', 'An embedded time-series database with a tiny footprint'),
    ('02', 'tinyfeeds/reader', 'TypeScript · ★ 8.1k · +310', 'Self-hosted RSS reader with full-text search'),
    ('03', 'nine-tails/termlog', 'Rust · ★ 2.4k · +288', 'Structured log viewer for the terminal'),
    ('04', 'coreq/quant', 'Python · ★ 5.6k · +240', 'Quantization toolkit for laptop GPUs'),
    ('05', 'singlebox/recipes', 'Ruby · ★ 1.1k · +180', 'Single-server deployment recipes and checklists'),
    ('06', 'blocksmith/atlas', 'TypeScript · ★ 3.9k · +150', 'Copy-paste UI blocks for Tailwind v4'),
]
HAD = [
    ('01', 'A Mechanical Keyboard Built From Scrap Relays', 'M. Okada · 3h', 'Sixty-one relays, one solenoid per key, and a click you can hear from the next room.'),
    ('02', 'Reviving a 1980s Oscilloscope With an ESP32', 'R. Alvarez · 6h', 'The CRT still works; the trigger board did not. A small microcontroller now stands in for it.'),
    ('03', 'Open-Source Weather Station Survives Its First Typhoon', 'S. Lindqvist · 9h', 'Solar, LoRa, and a 3D-printed housing that turned out to matter more than the electronics.'),
    ('04', 'The Physics of a Perfect Pour-Over', 'M. Okada · 13h', 'Flow rate, grind size and a load cell under the kettle.'),
    ('05', 'The Telegraph Repeater, Revisited', 'R. Alvarez · 20h', 'How a nineteenth-century relay kept a signal alive across a continent.'),
    ('06', 'A Week of Small Radios', 'S. Lindqvist · 22h', 'Three pocket receivers, one antenna theory refresher.'),
]
