"""第六轮：纸报定稿方向（浅纸色）。按真实数据密度重构版面，原创墨线插图。"""
from common import *
from pages_warm import doc

GROUND, PAPER, INK, INK2, GREEN = '#1D1D1B', '#E8E3DA', '#1D1D1B', '#55504B', '#96B59F'
RULE = 'rgba(29, 29, 27, 0.35)'
NAME = "'Bodoni Moda', 'Noto Serif SC', 'Songti SC', serif"
SERIF = "'Newsreader', 'Noto Serif SC', 'Songti SC', serif"
KICK = "'Oswald', 'Noto Sans SC', 'PingFang SC', sans-serif"
FONTS = ('https://fonts.googleapis.com/css2?family=Bodoni+Moda:opsz,wght@6..96,400..900&family=Newsreader:ital,opsz,wght@0,6..72,400..700;1,6..72,400..700'
         '&family=Oswald:wght@400;500;600&family=Noto+Serif+SC:wght@400;600;900&family=Noto+Sans+SC:wght@400;500&display=swap')
H = 4000

# ---- 样例数据：完整一期。全部虚构。
HN30 = list(HN) + [
    ('09', 'What I learned running a mail server for ten years', '▲ 88 · 64 评论 · 16h'),
    ('10', 'A visual explanation of B-tree splits', '▲ 84 · 12 评论 · 17h'),
    ('11', 'Why our team writes design docs in plain text', '▲ 79 · 41 评论 · 17h'),
    ('12', 'Measuring latency from the Pacific edge', '▲ 76 · 9 评论 · 18h'),
    ('13', 'Show HN: A tiny static site generator in 200 lines', '▲ 72 · 33 评论 · 18h'),
    ('14', 'The forgotten history of the teletype', '▲ 70 · 15 评论 · 19h'),
    ('15', 'Rewriting a CLI in Go, one year later', '▲ 66 · 27 评论 · 19h'),
    ('16', 'How a compiler chooses register allocation', '▲ 63 · 8 评论 · 20h'),
    ('17', 'Ask HN: Best way to archive a personal wiki?', '▲ 61 · 58 评论 · 20h'),
    ('18', 'Type inference for humans', '▲ 58 · 21 评论 · 21h'),
    ('19', 'A garden of forking transactions', '▲ 55 · 11 评论 · 21h'),
    ('20', 'Debugging a kernel panic with only serial output', '▲ 52 · 14 评论 · 22h'),
    ('21', 'On the joy of small tools', '▲ 50 · 30 评论 · 22h'),
    ('22', 'Tracing HTTP requests through a home lab', '▲ 48 · 7 评论 · 22h'),
    ('23', 'The economics of a solo SaaS in 2026', '▲ 47 · 66 评论 · 23h'),
    ('24', 'A plain-text budgeting workflow that stuck', '▲ 45 · 19 评论 · 23h'),
    ('25', 'Why fonts look different on every screen', '▲ 44 · 23 评论 · 23h'),
    ('26', 'Notes from porting a game to the browser', '▲ 42 · 10 评论 · 1d'),
    ('27', 'Building a weather station that survives winter', '▲ 41 · 13 评论 · 1d'),
    ('28', 'A short history of the pager', '▲ 40 · 6 评论 · 1d'),
    ('29', 'Show HN: Read RSS in your terminal', '▲ 39 · 17 评论 · 1d'),
    ('30', 'What makes a keyboard feel fast', '▲ 38 · 25 评论 · 1d'),
]
GH25 = list(GH) + [
    ('07', 'harborline/queue', 'Go · ★ 6.2k · +140', 'A boring, durable job queue on top of a single database'),
    ('08', 'pinecone-labs/sketch', 'TypeScript · ★ 2.9k · +130', 'Whiteboard primitives for the browser'),
    ('09', 'okonomi/shell', 'Rust · ★ 1.8k · +120', 'A shell that remembers what you meant'),
    ('10', 'littlebus/mqtt', 'C · ★ 4.4k · +110', 'A single-header MQTT client for microcontrollers'),
    ('11', 'quietfox/reader', 'Swift · ★ 980 · +98', 'Distraction-free reading for long articles'),
    ('12', 'gravel/db', 'Zig · ★ 1.3k · +91', 'An embedded key-value store with a tiny footprint'),
    ('13', 'northstar/ci', 'Go · ★ 3.1k · +85', 'Run your pipeline locally, exactly like the server'),
    ('14', 'papertrail-dev/notes', 'TypeScript · ★ 720 · +80', 'Local-first notes with plain-text storage'),
    ('15', 'seaglass/ui', 'TypeScript · ★ 2.2k · +76', 'Accessible components with zero runtime styling'),
    ('16', 'ferrite/serial', 'Rust · ★ 640 · +70', 'A serial monitor that understands your protocol'),
    ('17', 'kite-tools/bench', 'Python · ★ 1.1k · +66', 'Reproducible microbenchmarks with statistics'),
    ('18', 'lantern/logs', 'Go · ★ 890 · +62', 'Structured logs, pretty for humans'),
    ('19', 'orchard/feeds', 'Ruby · ★ 410 · +58', 'Fetch, normalise and archive RSS feeds'),
    ('20', 'tidepool/sync', 'Rust · ★ 1.5k · +55', 'Conflict-free sync for small apps'),
    ('21', 'moth/fonts', 'Python · ★ 530 · +52', 'Subset and inspect variable fonts'),
    ('22', 'stonebridge/http', 'C · ★ 2.7k · +50', 'A small, well-tested HTTP/1.1 server'),
    ('23', 'coreq/serve', 'Python · ★ 960 · +48', 'Serve quantised models on a laptop'),
    ('24', 'nine-tails/tail', 'Rust · ★ 380 · +47', 'Follow many files at once, with filters'),
    ('25', 'blocksmith/forms', 'TypeScript · ★ 610 · +45', 'Form patterns you can copy into any stack'),
]
HAD12 = list(HAD) + [
    ('07', 'Turning a Broken Printer Into a Plotter', 'M. Okada · 1d', 'Two stepper motors, a pen holder, and a weekend of firmware.'),
    ('08', 'The Cheapest Spectrum Analyser You Will Ever Build', 'R. Alvarez · 1d', 'A dongle, a shielded box, and a lot of averaging.'),
    ('09', 'A Bicycle Dynamo That Charges Your Phone Properly', 'S. Lindqvist · 1d', 'Regulation matters more than the magnet.'),
    ('10', 'Mapping a Basement With a Rotating Laser', 'M. Okada · 1d', 'Point clouds from parts you already own.'),
    ('11', 'Inside a Vintage Telephone Exchange Relay', 'R. Alvarez · 1d', 'Why it clicked, and why it still works.'),
    ('12', 'Reading Soil Moisture Without Corroding the Probe', 'S. Lindqvist · 1d', 'Capacitive sensing beats bare copper every time.'),
]

# ---- 插图：墨线木刻手法，原创。
def frame(svg_inner, w, h, caption):
    return ('<figure style="margin: 0; display: flex; flex-direction: column; gap: 6px; width: ' + str(w + 14) + 'px;">'
            '<div style="border: 1px solid ' + INK + '; background: ' + PAPER + '; padding: 6px;"><svg viewBox="0 0 ' + str(w) + ' ' + str(h) + '" width="' + str(w) + '" height="' + str(h) + '" style="display: block;" fill="none" stroke="' + INK + '" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + svg_inner + '</svg></div>'
            '<figcaption style="font-family: ' + KICK + '; font-size: 11px; letter-spacing: 0.12em; text-transform: uppercase; color: ' + INK2 + ';">' + caption + '</figcaption></figure>')

def hatch(x, y, w, h, step=5):
    out = ''
    d = -h
    while d < w:
        t1, t2 = max(d, 0), min(d + h, w)
        if t2 <= t1:
            d += step
            continue
        x1, y1 = x + t1, y + (t1 - d)
        x2, y2 = x + t2, y + (t2 - d)
        out += '<line x1="' + str(round(x1, 1)) + '" y1="' + str(round(y1, 1)) + '" x2="' + str(round(x2, 1)) + '" y2="' + str(round(y2, 1)) + '" stroke-width="0.9"></line>'
        d += step
    return out

def ill_sunrise():
    rays = ''.join('<line x1="%s" y1="%s" x2="%s" y2="%s"></line>' % (round(130 + 44 * __import__('math').cos(a), 1), round(84 - 44 * __import__('math').sin(a), 1), round(130 + 56 * __import__('math').cos(a), 1), round(84 - 56 * __import__('math').sin(a), 1))
                   for a in [0.35, 0.7, 1.05, 1.4, 1.75, 2.1, 2.45, 2.8])
    return ('<path d="M96 84 a34 34 0 0 1 68 0 z" fill="' + GREEN + '"></path>'
            + '<path d="M96 84 a34 34 0 0 1 68 0"></path>' + rays
            + '<line x1="14" y1="84" x2="246" y2="84" stroke-width="2"></line>'
            '<path d="M14 118 C 50 100 84 104 118 112 S 190 122 246 108"></path><path d="M14 126 C 70 112 120 118 160 124 S 220 130 246 122" stroke-width="1"></path>'
            '<path d="M14 42 l6 -12 l6 16 l6 -20 l6 18 l6 -14 l6 16 l6 -12 l6 10 l6 -14 l6 12 l6 -12 l6 10 l4 -6" stroke-width="1.4"></path>'
            '<rect x="90" y="24" width="30" height="32" fill="' + PAPER + '"></rect>' + hatch(92, 26, 26, 28, 4)
            + '<path d="M120 40 c 14 -18 28 -18 42 0 s 28 18 42 0 s 28 -18 42 0" stroke-width="1.6"></path>')

def ill_bubbles():
    return ('<rect x="10" y="10" width="62" height="34" rx="8" fill="' + PAPER + '"></rect><path d="M22 44 l-4 10 l12 -10"></path>'
            '<rect x="48" y="30" width="62" height="34" rx="8" fill="' + PAPER + '"></rect>' + hatch(54, 35, 50, 24, 6)
            + '<path d="M96 64 l4 10 l-12 -10"></path>'
            '<polygon points="24,22 30,32 18,32" fill="' + INK + '"></polygon><line x1="36" y1="27" x2="62" y2="27"></line>')

def ill_branches():
    return ('<line x1="30" y1="72" x2="30" y2="14"></line>'
            '<path d="M30 46 C 40 30 56 30 70 30"></path><path d="M70 30 C 84 30 92 22 100 16"></path>'
            '<circle cx="30" cy="66" r="4" fill="' + PAPER + '"></circle><circle cx="30" cy="46" r="4" fill="' + PAPER + '"></circle><circle cx="30" cy="24" r="4" fill="' + PAPER + '"></circle>'
            '<circle cx="70" cy="30" r="4" fill="' + PAPER + '"></circle>'
            '<polygon points="100,6 103,13 110,13 104,17 106,24 100,20 94,24 96,17 90,13 97,13" fill="' + GREEN + '" stroke-width="1.2"></polygon>')

def ill_solder():
    return ('<path d="M14 68 L 52 40" stroke-width="6"></path><path d="M52 40 L 82 20" stroke-width="1.8"></path>'
            '<path d="M84 20 c 3 -4 -2 -6 2 -10 s 5 -2 3 -5"></path>'
            '<rect x="58" y="48" width="34" height="22" fill="' + PAPER + '"></rect>' + hatch(60, 50, 30, 18, 5)
            + ''.join('<line x1="%d" y1="70" x2="%d" y2="76" stroke-width="1.2"></line>' % (x, x) for x in (64, 72, 80, 88))
            + ''.join('<line x1="%d" y1="48" x2="%d" y2="42" stroke-width="1.2"></line>' % (x, x) for x in (64, 72, 80, 88)))

def stamp():
    return ('<svg viewBox="0 0 64 64" width="56" height="56" fill="none" stroke="' + INK + '" stroke-width="1.6" style="display: block;">'
            '<circle cx="32" cy="32" r="29"></circle><circle cx="32" cy="32" r="23" stroke-dasharray="3 3" stroke-width="1"></circle>'
            '<text x="32" y="37" text-anchor="middle" font-family="' + NAME.replace("'", '') + '" font-size="15" font-weight="700" fill="' + INK + '" stroke="none">LP</text></svg>')

# ---- 版面
def kicker(text, color=INK, size=14):
    return '<span style="font-family: ' + KICK + '; font-size: ' + str(size) + 'px; font-weight: 500; letter-spacing: 0.12em; text-transform: uppercase; color: ' + color + ';">' + text + '</span>'

def badge(text):
    return '<span style="font-family: ' + KICK + '; font-size: 11px; font-weight: 600; letter-spacing: 0.08em; background: ' + GREEN + '; color: ' + INK + '; padding: 3px 7px; border-radius: 2px; white-space: nowrap;">' + text + '</span>'

def rule(px=1):
    return '<div style="height: ' + str(px) + 'px; background: ' + INK + ';"></div>'

def section_head(title, sub, ill):
    return ('<div style="display: flex; align-items: flex-end; justify-content: space-between; padding: 20px 0 14px 0;">'
            '<div style="display: flex; flex-direction: column; gap: 6px;"><h2 style="margin: 0; font-family: ' + NAME + '; font-size: 40px; font-weight: 700; line-height: 1; letter-spacing: 0.01em;">' + title + '</h2>' + mono(sub, INK2) + '</div>' + ill + '</div>')

def press():
    ears = ('<div style="display: flex; align-items: center; justify-content: space-between; padding: 14px 0; border-bottom: 1px solid ' + INK + ';">'
            '<div style="display: flex; gap: 22px; align-items: baseline;"><span style="font-family: ' + KICK + '; font-size: 14px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; border-bottom: 2px solid ' + INK + '; padding-bottom: 2px;">日刊</span>' + kicker('周刊', INK2) + kicker('搜索', INK2) + '</div>'
            '<span style="font-family: ' + KAI + '; font-size: 20px;">2026年9月8日 · 星期二</span>'
            '<div style="display: flex; align-items: center; gap: 14px;">' + mono('06:12 发布 · 67 条', INK2) + '<span style="width: 30px; height: 30px; border-radius: 50%; border: 1px solid ' + INK + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 15, INK) + '</span></div></div>')
    nameplate = ('<div style="background: ' + INK + '; margin-top: 20px; padding: 6px 24px 18px 24px; display: flex; flex-direction: column; align-items: center; gap: 4px;">'
                 '<span style="font-family: ' + NAME + '; font-size: 196px; line-height: 0.92; font-weight: 900; letter-spacing: 0.01em; text-transform: uppercase; color: ' + PAPER + ';">lowpass</span>'
                 '<span style="font-family: ' + KAI + '; font-size: 22px; color: ' + PAPER + '; opacity: 0.85;">滤掉噪音，留下信号。</span></div>')
    stat = lambda k, v: '<div style="display: flex; justify-content: space-between; gap: 16px; padding: 9px 0; border-bottom: 1px solid ' + RULE + ';"><span style="font-size: 16px;">' + k + '</span>' + mono(v, INK2) + '</div>'
    band = ('<div style="display: grid; grid-template-columns: 5fr 4fr 3fr; gap: 40px; padding: 28px 0 24px 0; align-items: end;">'
            '<div style="display: flex; flex-direction: column; gap: 10px;"><span style="font-family: ' + KAI + '; font-size: 64px; line-height: 1;">9月8日 <span style="font-size: 28px; color: ' + INK2 + ';">星期二</span></span>'
            '<span style="font-size: 18px; font-style: italic; color: ' + INK2 + ';">今天的一期在 06:12 装订完成，三个来源，读完就能合上。</span></div>'
            '<div style="display: flex; flex-direction: column;">' + stat('来源', '3 个') + stat('条目', '67 条 · 30 / 25 / 12') + stat('抓取用时', '4 分 12 秒') + stat('昨日', '71 条 · 全部成功') + '</div>'
            '<div style="display: flex; justify-content: flex-end;">' + frame(ill_sunrise(), 260, 138, '低通滤波') + '</div></div>')
    idx = lambda t, n, active=False: ('<a href="#" style="display: inline-flex; align-items: baseline; gap: 8px; font-family: ' + KICK + '; font-size: 14px; font-weight: 500; letter-spacing: 0.12em; text-transform: uppercase; color: ' + INK + ';' + (' border-bottom: 2px solid ' + INK + '; padding-bottom: 2px;' if active else '') + '"><span>' + t + '</span>' + mono(str(n), INK2) + '</a>')
    ctrl = lambda l, il=None, ir=None, off=False: ('<span style="display: inline-flex; align-items: center; gap: 6px; height: 34px; padding: 0 12px; border: 1px solid ' + (RULE if off else INK) + '; font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.1em; text-transform: uppercase; color: ' + (INK2 if off else INK) + ';">'
                                                 + (icon(il, 14, INK2 if off else INK) if il else '') + '<span>' + l + '</span>' + (icon(ir, 14, INK2 if off else INK) if ir else '') + '</span>')
    index_bar = ('<div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-top: 2px solid ' + INK + '; border-bottom: 1px solid ' + INK + ';">'
                 '<div style="display: flex; gap: 28px;">' + idx('Hacker News', 30, True) + idx('GitHub Trending', 25) + idx('Hackaday', 12) + '</div>'
                 '<div style="display: flex; gap: 8px;">' + ctrl('9月7日', il='chevron-left') + ctrl('归档') + ctrl('9月9日', ir='chevron-right', off=True) + '</div></div>')
    # Hacker News：三栏各十条
    def hn_item(r, t, m):
        return ('<div style="display: flex; gap: 12px; padding: 12px 0; border-bottom: 1px solid ' + RULE + ';">'
                '<span style="font-family: ' + NAME + '; font-size: 20px; font-weight: 700; line-height: 1.1; width: 30px; flex: none;">' + r.lstrip('0') + '</span>'
                '<div style="display: flex; flex-direction: column; gap: 4px; min-width: 0;"><a href="#" style="font-size: 17px; line-height: 1.35; font-weight: 500;">' + t + '</a>' + mono(m, INK2) + '</div></div>')
    hn_cols = ''.join('<div style="display: flex; flex-direction: column;' + (' border-left: 1px solid ' + RULE + '; padding-left: 24px;' if c else '') + '">' + ''.join(hn_item(*x) for x in HN30[c * 10:(c + 1) * 10]) + '</div>' for c in range(3))
    hn = ('<div id="hn">' + section_head('Hacker News', '前 30 条 · 榜单顺序 · 分数与评论数为抓取时刻', frame(ill_bubbles(), 120, 78, '讨论')) + rule(1)
          + '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0 24px; padding: 4px 0 28px 0;">' + hn_cols + '</div></div>')
    # GitHub：完整表格
    COLS = '36px minmax(0, 2fr) minmax(0, 3fr) 96px 88px 84px'
    def gh_row(r, name, m, desc):
        lang, stars, delta = [x.strip() for x in m.split('·')]
        return ('<div style="display: grid; grid-template-columns: ' + COLS + '; gap: 18px; align-items: baseline; padding: 10px 0; border-bottom: 1px solid ' + RULE + ';">'
                '<span style="font-family: ' + NAME + '; font-size: 17px; font-weight: 700;">' + r.lstrip('0') + '</span>'
                '<a href="#" style="font-size: 17px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">' + name + '</a>'
                '<span style="font-style: italic; font-size: 15px; color: ' + INK2 + '; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">' + desc + '</span>'
                + mono(lang, INK2) + mono(stars, INK) + '<span>' + badge(delta) + '</span></div>')
    gh_head = ('<div style="display: grid; grid-template-columns: ' + COLS + '; gap: 18px; padding: 10px 0 6px 0;">' + ''.join(kicker(x, INK2, 11) for x in ['#', '仓库', '简介', '语言', 'Star', '今日']) + '</div>')
    gh = ('<div id="gh">' + section_head('GitHub Trending', '今日 25 个 · 综合榜 · 今日新增 star 降序', frame(ill_branches(), 120, 78, '分支')) + rule(1) + gh_head + ''.join(gh_row(*x) for x in GH25) + '<div style="height: 28px;"></div></div>')
    # Hackaday：三栏四行文字卡
    def had_card(r, t, m, s):
        return ('<article style="display: flex; flex-direction: column; gap: 10px; border-top: 2px solid ' + INK + '; padding: 14px 0 8px 0;">'
                '<div style="display: flex; justify-content: space-between; align-items: baseline;"><span style="font-family: ' + NAME + '; font-size: 20px; font-weight: 700;">' + r.lstrip('0') + '</span>' + mono(m, INK2) + '</div>'
                '<a href="#" style="font-size: 19px; line-height: 1.3; font-weight: 500;">' + t + '</a>'
                '<span style="font-size: 15px; line-height: 1.5; color: ' + INK2 + ';">' + s + '</span></article>')
    had = ('<div id="had">' + section_head('Hackaday', '近 24 小时 12 篇 · 发布时间倒序 · 摘要取自原文首段', frame(ill_solder(), 120, 78, '焊接')) + rule(1)
           + '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px 28px; padding: 12px 0 28px 0;">' + ''.join(had_card(*x) for x in HAD12) + '</div></div>')
    footer = (rule(2) + '<div style="display: flex; align-items: center; justify-content: space-between; padding: 18px 0 8px 0;">'
              '<div style="display: flex; align-items: center; gap: 16px;">' + stamp() + '<div style="display: flex; flex-direction: column; gap: 4px;">' + mono('明早 06:00 · 下一期', INK2) + '<a href="#" style="font-size: 16px; font-weight: 500;">最新周刊 · 第 36 周 · 阮一峰周刊第 366 期 →</a></div></div>'
              '<div style="display: flex; gap: 8px;">' + ctrl('回到顶部', il='chevron-left') + ctrl('9月7日', il='chevron-left') + ctrl('归档') + '</div></div>')
    sheet = ('<div style="width: 1240px; margin: 40px auto 56px auto; padding: 0 40px 28px 40px; box-sizing: border-box; background: ' + PAPER + '; color: ' + INK + '; '
             'background-image: repeating-linear-gradient(0deg, rgba(29, 29, 27, 0.03) 0 1px, transparent 1px 3px), repeating-linear-gradient(90deg, rgba(255, 255, 255, 0.14) 0 1px, transparent 1px 4px); box-shadow: 0 30px 80px rgba(0, 0, 0, 0.5);">'
             + ears + nameplate + band + index_bar + hn + gh + had + footer + '</div>\n')
    css = ('    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-underline-offset: 3px; }\n')
    return doc(sheet, FONTS, GROUND, INK, SERIF, css, H)

# ---- 定稿方向修订：每源只取前 10（产品负责人决定，少即是多）。三栏并排，一版看完。
def front():
    ears = ('<div style="display: flex; align-items: center; justify-content: space-between; padding: 14px 0; border-bottom: 1px solid ' + INK + ';">'
            '<div style="display: flex; gap: 22px; align-items: baseline;"><span style="font-family: ' + KICK + '; font-size: 14px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; border-bottom: 2px solid ' + INK + '; padding-bottom: 2px;">日刊</span>' + kicker('周刊', INK2) + kicker('搜索', INK2) + '</div>'
            '<span style="font-family: ' + KAI + '; font-size: 20px;">2026年9月8日 · 星期二</span>'
            '<div style="display: flex; align-items: center; gap: 14px;">' + mono('06:12 发布 · 30 条', INK2) + '<span style="width: 30px; height: 30px; border-radius: 50%; border: 1px solid ' + INK + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 15, INK) + '</span></div></div>')
    nameplate = ('<div style="background: ' + INK + '; margin-top: 20px; padding: 6px 24px 18px 24px; display: flex; flex-direction: column; align-items: center; gap: 4px;">'
                 '<span style="font-family: ' + NAME + '; font-size: 196px; line-height: 0.92; font-weight: 900; letter-spacing: 0.01em; text-transform: uppercase; color: ' + PAPER + ';">lowpass</span>'
                 '<span style="font-family: ' + KAI + '; font-size: 22px; color: ' + PAPER + '; opacity: 0.85;">滤掉噪音，留下信号。</span></div>')
    stat = lambda k, v: '<div style="display: flex; justify-content: space-between; gap: 16px; padding: 9px 0; border-bottom: 1px solid ' + RULE + ';"><span style="font-size: 16px;">' + k + '</span>' + mono(v, INK2) + '</div>'
    band = ('<div style="display: grid; grid-template-columns: 5fr 4fr 3fr; gap: 40px; padding: 28px 0 24px 0; align-items: end;">'
            '<div style="display: flex; flex-direction: column; gap: 10px;"><span style="font-family: ' + KAI + '; font-size: 64px; line-height: 1;">9月8日 <span style="font-size: 28px; color: ' + INK2 + ';">星期二</span></span>'
            '<span style="font-size: 18px; font-style: italic; color: ' + INK2 + ';">每个来源只留前十，一版读完。</span></div>'
            '<div style="display: flex; flex-direction: column;">' + stat('来源', '3 个') + stat('条目', '30 条 · 每源 10') + stat('抓取用时', '4 分 12 秒') + stat('昨日', '30 条 · 全部成功') + '</div>'
            '<div style="display: flex; justify-content: flex-end;">' + frame(ill_sunrise(), 260, 138, '低通滤波') + '</div></div>')
    ctrl = lambda l, il=None, ir=None, off=False: ('<span style="display: inline-flex; align-items: center; gap: 6px; height: 34px; padding: 0 12px; border: 1px solid ' + (RULE if off else INK) + '; font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.1em; text-transform: uppercase; color: ' + (INK2 if off else INK) + ';">'
                                                 + (icon(il, 14, INK2 if off else INK) if il else '') + '<span>' + l + '</span>' + (icon(ir, 14, INK2 if off else INK) if ir else '') + '</span>')
    bar = ('<div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-top: 2px solid ' + INK + '; border-bottom: 1px solid ' + INK + ';">'
           '<div style="display: flex; gap: 28px; align-items: baseline;">' + kicker('本期三栏') + mono('Hacker News 10 · GitHub Trending 10 · Hackaday 10', INK2) + '</div>'
           '<div style="display: flex; gap: 8px;">' + ctrl('9月7日', il='chevron-left') + ctrl('归档') + ctrl('9月9日', ir='chevron-right', off=True) + '</div></div>')
    def col_head(title, sub, ill):
        return ('<div style="display: flex; flex-direction: column; gap: 12px; padding: 20px 0 14px 0; border-bottom: 1px solid ' + INK + ';">' + ill
                + '<div style="display: flex; flex-direction: column; gap: 6px;"><h2 style="margin: 0; font-family: ' + NAME + '; font-size: 30px; font-weight: 700; line-height: 1.05;">' + title + '</h2>' + mono(sub, INK2) + '</div></div>')
    def row(r, title, meta, desc=None, badge_text=None):
        parts = ['<a href="#" style="font-size: 17px; line-height: 1.35; font-weight: 500;">' + title + '</a>']
        if desc:
            parts.append('<span style="font-size: 14.5px; line-height: 1.45; color: ' + INK2 + ';">' + desc + '</span>')
        meta_html = mono(meta, INK2) if not badge_text else ('<span style="display: inline-flex; align-items: center; gap: 8px;">' + mono(meta, INK2) + badge(badge_text) + '</span>')
        parts.append(meta_html)
        return ('<div style="display: flex; gap: 12px; padding: 12px 0; border-bottom: 1px solid ' + RULE + ';">'
                '<span style="font-family: ' + NAME + '; font-size: 20px; font-weight: 700; line-height: 1.1; width: 30px; flex: none;">' + r.lstrip('0') + '</span>'
                '<div style="display: flex; flex-direction: column; gap: 4px; min-width: 0;">' + ''.join(parts) + '</div></div>')
    def col_foot(label):
        return ('<a href="#" style="display: inline-flex; align-items: center; gap: 6px; padding: 16px 0 0 0; font-family: ' + KICK + '; font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;"><span>' + label + '</span>' + icon('arrow-up-right', 14, INK) + '</a>')
    hn_col = ('<div style="display: flex; flex-direction: column;">' + col_head('Hacker News', '前 10 条 · 榜单顺序', frame(ill_bubbles(), 120, 78, '讨论'))
              + ''.join(row(r, t, m) for r, t, m in HN30[:10]) + col_foot('去 Hacker News 看完整榜单') + '</div>')
    def gh_row(r, name, m, desc):
        lang, stars, delta = [x.strip() for x in m.split('·')]
        return row(r, name, lang + ' · ' + stars, desc, delta)
    gh_col = ('<div style="display: flex; flex-direction: column; border-left: 1px solid ' + RULE + '; padding-left: 28px;">' + col_head('GitHub Trending', '今日前 10 · 新增 star 降序', frame(ill_branches(), 120, 78, '分支'))
              + ''.join(gh_row(*x) for x in GH25[:10]) + col_foot('去 GitHub 看完整榜单') + '</div>')
    had_col = ('<div style="display: flex; flex-direction: column; border-left: 1px solid ' + RULE + '; padding-left: 28px;">' + col_head('Hackaday', '近 24 小时最新 10 篇', frame(ill_solder(), 120, 78, '焊接'))
               + ''.join(row(r, t, m, s) for r, t, m, s in HAD12[:10]) + col_foot('去 Hackaday 看全部') + '</div>')
    columns = '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0 28px; padding: 0 0 28px 0;">' + hn_col + gh_col + had_col + '</div>'
    footer = (rule(2) + '<div style="display: flex; align-items: center; justify-content: space-between; padding: 18px 0 8px 0;">'
              '<div style="display: flex; align-items: center; gap: 16px;">' + stamp() + '<div style="display: flex; flex-direction: column; gap: 4px;">' + mono('明早 06:00 · 下一期', INK2) + '<a href="#" style="font-size: 16px; font-weight: 500;">最新周刊 · 第 36 周 · 阮一峰周刊第 366 期 →</a></div></div>'
              '<div style="display: flex; gap: 8px;">' + ctrl('9月7日', il='chevron-left') + ctrl('归档') + ctrl('9月9日', ir='chevron-right', off=True) + '</div></div>')
    sheet = ('<div style="width: 1240px; margin: 40px auto 56px auto; padding: 0 40px 28px 40px; box-sizing: border-box; background: ' + PAPER + '; color: ' + INK + '; '
             'background-image: repeating-linear-gradient(0deg, rgba(29, 29, 27, 0.03) 0 1px, transparent 1px 3px), repeating-linear-gradient(90deg, rgba(255, 255, 255, 0.14) 0 1px, transparent 1px 4px); box-shadow: 0 30px 80px rgba(0, 0, 0, 0.5);">'
             + ears + nameplate + band + bar + columns + footer + '</div>\n')
    css = ('    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-underline-offset: 3px; }\n')
    return doc(sheet, FONTS, GROUND, INK, SERIF, css, 2500)
