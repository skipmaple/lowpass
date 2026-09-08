"""第五轮：纸报。参考 niccolomiranda.com 的"深色桌面上一张纸报"气质：纸色、墨线栏框、巨型高对比报头、轻衬线正文、窄体大写栏目、一点绿。"""
from common import *
from pages_warm import doc

GROUND, INK, INK2, GREEN, RED = '#1D1D1B', '#1D1D1B', '#55504B', '#96B59F', '#C03F13'
NAME = "'Bodoni Moda', 'Noto Serif SC', 'Songti SC', serif"
SERIF = "'Newsreader', 'Noto Serif SC', 'Songti SC', serif"
KICK = "'Oswald', 'Noto Sans SC', 'PingFang SC', sans-serif"
FONTS = ('https://fonts.googleapis.com/css2?family=Bodoni+Moda:opsz,wght@6..96,400..900&family=Newsreader:ital,opsz,wght@0,6..72,200..800;1,6..72,200..800'
         '&family=Oswald:wght@400;500;600&family=Noto+Serif+SC:wght@400;600;900&family=Noto+Sans+SC:wght@400;500&display=swap')
H = 2300

def page(body, paper):
    css = ('    a { color: ' + INK + '; text-decoration: none; }\n    a:hover { color: ' + INK + '; text-decoration: underline; text-underline-offset: 3px; }\n')
    return doc(body, FONTS, GROUND, INK, SERIF, css, H)

def rule(px=1, margin='0'):
    return '<div style="height: ' + str(px) + 'px; background: ' + INK + '; margin: ' + margin + ';"></div>'

def kicker(text):
    return '<span style="font-family: ' + KICK + '; font-size: 15px; font-weight: 500; letter-spacing: 0.12em; text-transform: uppercase; color: ' + INK + ';">' + text + '</span>'

def badge(text, bg=GREEN, fg=INK):
    return '<span style="font-family: ' + KICK + '; font-size: 11px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; background: ' + bg + '; color: ' + fg + '; padding: 3px 7px; border-radius: 2px;">' + text + '</span>'

def section_head(title, count, right=''):
    return ('<div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 0;">'
            '<div style="display: flex; align-items: center; gap: 14px;">' + kicker(title) + mono(count, INK2) + '</div>' + right + '</div>')

def paper_page(paper, grain_dark, grain_light):
    ears = ('<div style="display: flex; align-items: center; justify-content: space-between; padding: 14px 0; border-bottom: 1px solid ' + INK + ';">'
            '<div style="display: flex; gap: 22px; align-items: baseline;">' + kicker('日刊') + kicker('周刊').replace('color: ' + INK, 'color: ' + INK2) + kicker('搜索').replace('color: ' + INK, 'color: ' + INK2) + '</div>'
            '<span style="font-family: ' + KAI + '; font-size: 20px; color: ' + INK + ';">2026年9月8日 · 星期二</span>'
            + mono('06:12 发布 · 本期 67 条', INK2) + '</div>')
    teaser_l = ('<div style="display: flex; flex-direction: column; gap: 10px;">'
                '<div style="height: 96px; border: 1px solid ' + INK + '; display: flex; align-items: center; justify-content: center; font-family: ' + NAME + '; font-size: 64px; font-weight: 700; color: ' + INK + ';">▲312</div>'
                '<div style="display: flex; align-items: center; gap: 8px;">' + kicker('Hacker News 头条') + badge('New') + '</div>'
                '<a href="#" style="font-size: 17px; line-height: 1.35; font-weight: 500;">Show HN: A terminal log viewer written in Rust</a>' + mono('145 评论 · 5h', INK2) + '</div>')
    teaser_c = ('<div style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 10px; padding: 0 24px;">'
                '<span style="font-family: ' + NAME + '; font-size: 34px; font-weight: 700; letter-spacing: 0.02em; text-transform: uppercase;">全部 67 条</span>'
                '<span style="font-style: italic; font-size: 20px; line-height: 1.4; color: ' + INK + ';">三个来源，一份早报，<br>读完就能合上。</span>'
                + mono('↓ 向下阅读', INK2) + '</div>')
    teaser_r = ('<div style="display: flex; flex-direction: column; gap: 10px;">'
                '<div style="height: 96px; border: 1px solid ' + INK + '; display: flex; align-items: center; justify-content: center; font-family: ' + NAME + '; font-size: 64px; font-weight: 700; color: ' + INK + ';">★12.3k</div>'
                '<div style="display: flex; align-items: center; gap: 8px;">' + kicker('GitHub 今日最热') + badge('+420') + '</div>'
                '<a href="#" style="font-size: 17px; line-height: 1.35; font-weight: 500;">acme/lowlatency-db</a>' + mono('Zig · An embedded time-series database', INK2) + '</div>')
    teasers = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 32px; padding: 24px 0 28px 0;">' + teaser_l + teaser_c + teaser_r + '</div>')
    nameplate = ('<div style="background: ' + INK + '; padding: 8px 24px 20px 24px; display: flex; flex-direction: column; align-items: center; gap: 6px;">'
                 '<span style="font-family: ' + NAME + '; font-size: 196px; line-height: 0.92; font-weight: 900; letter-spacing: 0.01em; text-transform: uppercase; color: ' + paper + ';">lowpass</span>'
                 '<span style="font-family: ' + KAI + '; font-size: 22px; color: ' + paper + '; opacity: 0.85;">滤掉噪音，留下信号。</span></div>')
    # Hacker News：头条 + 双栏编号列表
    lead = ('<div style="display: flex; flex-direction: column; gap: 14px; padding-right: 32px; border-right: 1px solid ' + INK + ';">'
            + kicker('头条') + '<a href="#" style="font-size: 40px; line-height: 1.1; font-weight: 500; letter-spacing: -0.01em;">' + HN[0][1] + '</a>'
            '<span style="font-style: italic; font-size: 19px; line-height: 1.45; color: ' + INK2 + ';">今日 Hacker News 榜首，讨论集中在单文件分发与终端渲染性能。</span>' + mono(HN[0][2], INK2)
            + '<a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">阅读原文 →</a></div>')
    def num_item(r, t, m):
        return ('<div style="display: flex; gap: 14px; padding: 12px 0; border-bottom: 1px solid ' + INK + ';">'
                '<span style="font-family: ' + NAME + '; font-size: 22px; font-weight: 700; width: 34px; flex: none; line-height: 1;">' + r.lstrip('0') + '</span>'
                '<div style="display: flex; flex-direction: column; gap: 4px;"><a href="#" style="font-size: 18px; line-height: 1.35; font-weight: 500;">' + t + '</a>' + mono(m, INK2) + '</div></div>')
    hn_cols = ('<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 28px;">'
               + '<div style="display: flex; flex-direction: column;">' + ''.join(num_item(*x) for x in HN[1:5]) + '</div>'
               + '<div style="display: flex; flex-direction: column;">' + ''.join(num_item(*x) for x in HN[5:8]) + '<div style="padding: 14px 0;"><a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">其余 22 条，转下一版 →</a></div></div></div>')
    hn = (rule(2) + section_head('Hacker News', '前 30 条', badge('06:12 抓取', 'transparent', INK2).replace('background: transparent;', 'border: 1px solid ' + INK2 + ';'))
          + rule(1) + '<div style="display: grid; grid-template-columns: 5fr 7fr; gap: 32px; padding: 24px 0 28px 0;">' + lead + hn_cols + '</div>')
    # GitHub：表格
    def gh_row(r, name, m, desc):
        lang, stars, delta = [x.strip() for x in m.split('·')]
        return ('<div style="display: grid; grid-template-columns: 40px minmax(0, 2fr) minmax(0, 3fr) 90px 70px 90px; gap: 20px; align-items: baseline; padding: 14px 0; border-bottom: 1px solid ' + INK + ';">'
                '<span style="font-family: ' + NAME + '; font-size: 20px; font-weight: 700;">' + r.lstrip('0') + '</span>'
                '<a href="#" style="font-size: 19px; font-weight: 500;">' + name + '</a>'
                '<span style="font-style: italic; font-size: 16px; color: ' + INK2 + ';">' + desc + '</span>'
                + mono(lang, INK2) + mono(stars, INK2) + badge(delta) + '</div>')
    gh = (rule(2) + section_head('GitHub Trending', '今日 25 个') + rule(1)
          + '<div style="display: grid; grid-template-columns: 40px minmax(0, 2fr) minmax(0, 3fr) 90px 70px 90px; gap: 20px; padding: 10px 0 6px 0;">'
          + ''.join(kicker(x).replace('font-size: 15px', 'font-size: 12px').replace('color: ' + INK, 'color: ' + INK2) for x in ['#', '仓库', '简介', '语言', 'Star', '今日']) + '</div>'
          + ''.join(gh_row(*x) for x in GH) + '<div style="padding: 14px 0 28px 0;"><a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">其余 19 个 →</a></div>')
    # Hackaday：三栏卡，带编号方块
    def had_card(r, t, m, s):
        return ('<div style="display: flex; flex-direction: column; gap: 12px; border: 1px solid ' + INK + '; padding: 18px;">'
                '<div style="height: 120px; border: 1px solid ' + INK + '; display: flex; align-items: flex-end; justify-content: flex-start; padding: 12px; background-image: repeating-linear-gradient(135deg, rgba(29, 29, 27, 0.12) 0 1px, transparent 1px 7px);">'
                '<span style="font-family: ' + NAME + '; font-size: 56px; font-weight: 900; line-height: 0.9;">' + r.lstrip('0') + '</span></div>'
                '<a href="#" style="font-size: 20px; line-height: 1.3; font-weight: 500;">' + t + '</a>'
                '<span style="font-size: 15px; line-height: 1.5; color: ' + INK2 + ';">' + s + '</span>' + mono(m, INK2) + '</div>')
    had = (rule(2) + section_head('Hackaday', '近 24 小时 12 篇') + rule(1)
           + '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; padding: 24px 0 20px 0;">' + ''.join(had_card(*x) for x in HAD[:3]) + '</div>'
           + '<div style="padding: 0 0 28px 0;"><a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">其余 9 篇 →</a></div>')
    footer = (rule(2) + '<div style="display: flex; align-items: center; justify-content: space-between; padding: 18px 0 8px 0;">'
              '<div style="display: flex; align-items: center; gap: 16px;"><span style="width: 44px; height: 44px; border-radius: 50%; border: 1.5px solid ' + INK + '; display: inline-flex; align-items: center; justify-content: center; font-family: ' + NAME + '; font-size: 12px; font-weight: 700; letter-spacing: 0.06em;">LP</span>'
              + mono('明早 06:00 · 下一期', INK2) + '</div>'
              '<div style="display: flex; gap: 24px; align-items: baseline;"><a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">← 9月7日</a>'
              '<a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">归档</a>'
              '<a href="#" style="font-family: ' + KICK + '; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; font-weight: 500;">周刊 · 第 36 周</a></div></div>')
    sheet = ('<div style="width: 1240px; margin: 40px auto 56px auto; padding: 0 40px 28px 40px; box-sizing: border-box; background: ' + paper + '; color: ' + INK + '; '
             'background-image: repeating-linear-gradient(0deg, ' + grain_dark + ' 0 1px, transparent 1px 3px), repeating-linear-gradient(90deg, ' + grain_light + ' 0 1px, transparent 1px 4px); box-shadow: 0 30px 80px rgba(0, 0, 0, 0.5);">'
             + ears + teasers + nameplate + hn + gh + had + footer + '</div>\n')
    return page(sheet, paper)

def paper_beige():
    return paper_page('#CDC6BE', 'rgba(29, 29, 27, 0.035)', 'rgba(255, 255, 255, 0.10)')

def paper_light():
    return paper_page('#E8E3DA', 'rgba(29, 29, 27, 0.03)', 'rgba(255, 255, 255, 0.14)')
