from common import *

def pill(label, selected=False, icon_right=None):
    style = ('display: inline-flex; align-items: center; gap: 6px; height: 32px; padding: 0 12px; border-radius: 999px; font-size: 13px; font-weight: 500; box-sizing: border-box; '
             + ('background: ' + PRESSED + '; border: 1px solid transparent;' if selected else 'border: 1px solid ' + BORDER_STRONG + ';'))
    left = icon('check', 14, INK) if selected else ''
    right = icon(icon_right, 14, INK) if icon_right else ''
    return '<span style="' + style + '">' + left + '<span>' + label + '</span>' + right + '</span>'

def text_tabs(active, labels):
    out = []
    for l in labels:
        if l == active:
            out.append('<span style="padding: 10px 0; font-size: 15px; font-weight: 500; color: #000000; border-bottom: 2px solid #000000; margin-bottom: -1px;">' + l + '</span>')
        else:
            out.append('<span style="padding: 10px 0; font-size: 15px; color: ' + INK64 + ';">' + l + '</span>')
    return '<div style="display: flex; gap: 24px; border-bottom: 1px solid ' + BORDER + ';">' + ''.join(out) + '</div>'

def search():
    header = ('<div style="padding: 56px 64px 32px 64px; display: flex; flex-direction: column; gap: 24px;">'
              '<h1 style="margin: 0; font-size: 28px; font-weight: 500; line-height: 1.2;">搜索</h1>'
              '<div style="display: flex; align-items: center; gap: 12px; height: 48px; width: 720px; padding: 0 16px; border: 1px solid #000000; border-radius: 8px; box-sizing: border-box; box-shadow: 0 0 0 3px ' + BORDER + ';">'
              + icon('search', 20, INK64) + '<span style="font-size: 16px; flex: 1;">终端 工具</span>' + icon('x', 18, INK44) + '</div>'
              '<div style="display: flex; flex-direction: column; gap: 16px; width: 720px;">'
              + text_tabs('全部', ['全部', '日刊', '周刊'])
              + '<div style="display: flex; gap: 8px; flex-wrap: wrap;">' + pill('Hacker News') + pill('GitHub Trending') + pill('Hackaday') + pill('阮一峰周刊', selected=True) + pill('近 30 天', icon_right='chevron-down') + '</div>'
              '</div></div>\n')
    results = [
        ('<mark>termlog</mark>：<mark>终端</mark>里的结构化日志查看器', '按字段过滤、折叠与高亮，Rust 编写，单文件分发。', '周刊 · 阮一峰周刊 · 第 366 期 · 工具 · 2026-09-04'),
        ('<mark>终端</mark>为什么仍是最好的界面', '可组合、可脚本、可搜索，四十年过去这三点没有被替代。', '周刊 · 阮一峰周刊 · 第 366 期 · 文章 · 2026-09-04'),
        ('一个<mark>终端</mark>下的日志<mark>工具</mark>，以及它的十个替代品', '作者比较了十个<mark>终端</mark>日志<mark>工具</mark>的过滤语法与性能。', '周刊 · 阮一峰周刊 · 第 364 期 · 文章 · 2026-08-21'),
        ('给<mark>终端</mark>加一层低通滤波', '过滤掉高频噪音输出，只保留值得看的行。', '周刊 · 阮一峰周刊 · 第 365 期 · <mark>工具</mark> · 2026-08-28'),
    ]
    items = ''
    for t, s, m in results:
        items += ('<article style="display: flex; flex-direction: column; gap: 6px;">'
                  '<a href="#" style="font-size: 16px; line-height: 1.5; color: #000000;">' + t + '</a>'
                  '<span style="font-size: 15px; line-height: 1.5; color: ' + INK64 + ';">' + s + '</span>'
                  '<div style="display: flex; align-items: center; gap: 16px; flex-wrap: wrap;">' + mono(m)
                  + '<a href="#" style="display: inline-flex; align-items: center; gap: 4px; font-size: 13px; font-weight: 500; color: #000000;"><span>所在期</span>' + icon('chevron-right', 14, INK) + '</a>'
                  + '<a href="#" style="display: inline-flex; align-items: center; gap: 4px; font-size: 13px; font-weight: 500; color: #000000;"><span>原文</span>' + icon('arrow-up-right', 14, INK) + '</a>'
                  '</div></article>')
    pager = ('<div style="display: flex; align-items: center; gap: 12px; padding-top: 24px;">' + button('上一页', 'outline', icon_left='chevron-left', disabled=True)
             + mono('1 / 1', INK44) + button('下一页', 'outline', icon_right='chevron-right', disabled=True) + '</div>')
    body = ('<div style="padding: 0 64px 80px 64px; display: flex; flex-direction: column; gap: 28px; width: 720px; box-sizing: content-box;">'
            + mono('4 条结果') + items + pager + '</div>\n')
    return document(topbar('搜索') + header + body, 1440, 1200)

def settings():
    header = ('<div style="padding: 56px 64px 40px 64px;"><h1 style="margin: 0; font-size: 28px; font-weight: 500; line-height: 1.2;">设置</h1></div>\n')
    account = ('<section style="display: flex; flex-direction: column; gap: 20px;">'
               '<h2 style="margin: 0; font-size: 18px; font-weight: 500;">账号</h2>'
               '<div style="display: flex; align-items: center; gap: 16px;">'
               '<span style="width: 48px; height: 48px; border-radius: 50%; background: ' + PRESSED + '; display: inline-flex; align-items: center; justify-content: center;">' + icon('user', 22, INK64) + '</span>'
               '<div style="display: flex; flex-direction: column; gap: 4px;"><span style="font-size: 16px; font-weight: 500;">林小满</span>' + mono('xiaoman@example.com') + '</div>'
               + pill('管理员') + '</div></section>\n')
    def prov(name, since):
        return ('<div style="display: grid; grid-template-columns: 160px minmax(0, 1fr) 20px; gap: 16px; align-items: center; padding: 14px 0;">'
                '<span style="font-size: 16px;">' + name + '</span>' + mono('已绑定 · ' + since) + icon('check', 18, INK64) + '</div>')
    providers = ('<section style="display: flex; flex-direction: column; gap: 8px;">'
                 '<h2 style="margin: 0 0 12px 0; font-size: 18px; font-weight: 500;">登录方式</h2>' + prov('Google', '2026-09-08') + prov('GitHub', '2026-09-08')
                 + '<span style="font-size: 13px; color: ' + INK44 + '; padding-top: 8px;">两种方式登录的是同一个账号。</span></section>\n')
    session = ('<section style="display: flex; flex-direction: column; gap: 20px;">'
               '<h2 style="margin: 0; font-size: 18px; font-weight: 500;">会话</h2>'
               '<div style="display: flex; align-items: center; gap: 16px;">' + button('登出', 'outline', icon_left='log-out') + label('会话 30 天有效，活跃自动续期') + '</div></section>\n')
    body = '<div style="padding: 0 64px 80px 64px; display: flex; flex-direction: column; gap: 56px; max-width: 720px;">' + account + providers + session + '</div>\n'
    return document(topbar(active='') + header + body, 1440, 760)

def components():
    def h(title, note=''):
        return ('<div style="display: flex; align-items: baseline; gap: 16px;"><h2 style="margin: 0; font-size: 18px; font-weight: 500;">' + title + '</h2>'
                + (label(note, INK64) if note else '') + '</div>')
    def sec(title, note, content):
        return '<section style="display: flex; flex-direction: column; gap: 24px; padding-bottom: 64px;">' + h(title, note) + content + '</section>\n'
    # 颜色
    swatches = [('#000000', '100%', '正文、图标'), (INK64, '64%', '辅助文字、次级导航'), (INK56, '56%', '元数据'), (INK44, '44%', '占位、序号、停用'),
                (BORDER_STRONG, '18%', '控件描边'), (BORDER, '10%', '分隔线'), (PRESSED, '9%', '按下、选中'), (HOVER, '5%', '悬停'), (ALT, '3%', '长列表交替底色')]
    sw = ''.join('<div style="display: flex; flex-direction: column; gap: 8px; width: 120px;"><span style="height: 56px; border-radius: 8px; background: ' + c + '; border: 1px solid ' + BORDER + ';"></span>'
                 + mono(p, INK) + '<span style="font-size: 13px; color: ' + INK64 + ';">' + u + '</span></div>' for c, p, u in swatches)
    colors = sec('颜色', '纯黑透明度阶梯，不用带色相的灰', '<div style="display: flex; gap: 16px; flex-wrap: wrap;">' + sw + '</div>')
    # 字体
    fonts = sec('字体', 'Inter 与 Noto Sans SC 为界面字；文楷只用于期头与标语；Maple Mono NL 只用于数据',
        '<div style="display: flex; flex-direction: column; gap: 20px;">'
        '<div style="display: flex; align-items: baseline; gap: 24px;"><span style="font-family: ' + KAI + '; font-size: 44px; line-height: 1.1;">9月8日 <span style="font-size: 22px; color: ' + INK64 + ';">星期二</span></span>' + mono('期头 · LXGW WenKai Screen 44 / 22', INK44) + '</div>'
        '<div style="display: flex; align-items: baseline; gap: 24px;"><span style="font-size: 28px; font-weight: 500; line-height: 1.2;">页面标题</span>' + mono('28 / 500', INK44) + '</div>'
        '<div style="display: flex; align-items: baseline; gap: 24px;"><span style="font-size: 18px; font-weight: 500;">章节标题</span>' + mono('18 / 500', INK44) + '</div>'
        '<div style="display: flex; align-items: baseline; gap: 24px;"><span style="font-size: 16px;">条目标题与正文</span>' + mono('16 / 400 · 行高 1.5', INK44) + '</div>'
        '<div style="display: flex; align-items: baseline; gap: 24px;"><span style="font-size: 15px; color: ' + INK64 + ';">摘要</span>' + mono('15 / 400 · 64%', INK44) + '</div>'
        '<div style="display: flex; align-items: baseline; gap: 24px;"><span style="font-size: 14px; font-weight: 500;">控件文字</span>' + mono('14 / 500', INK44) + '</div>'
        '<div style="display: flex; align-items: baseline; gap: 24px;">' + mono('▲ 312 · 145 评论 · 5h    ★ 12.3k · +420    2026-W36 · 06:12') + mono('元数据 · Maple Mono NL 13 · 56%', INK44) + '</div>'
        '</div>')
    # 按钮
    hover_btn = button('悬停', 'outline').replace('background: #FFFFFF;', 'background: ' + HOVER + ';')
    pressed_btn = button('按下', 'outline').replace('background: #FFFFFF;', 'background: ' + PRESSED + ';')
    buttons = sec('按钮', '高 40，圆角 8，一个页面只有一个填充主按钮；移动端控件高 44',
        '<div style="display: flex; gap: 12px; flex-wrap: wrap; align-items: center;">' + button('主要操作', 'primary') + button('次要操作', 'outline') + button('幽灵', 'ghost')
        + hover_btn + pressed_btn + button('停用', 'outline', disabled=True) + button('带图标', 'outline', icon_left='refresh-cw') + '</div>')
    # 输入
    inputs = sec('输入', '默认描边 18%；聚焦描边 100% 加 3px 10% 外圈；搜索页主输入高 48',
        '<div style="display: flex; gap: 16px; flex-wrap: wrap;">'
        '<div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 12px; border: 1px solid ' + BORDER_STRONG + '; border-radius: 8px; box-sizing: border-box; color: ' + INK44 + '; font-size: 14px;">' + icon('search', 18, INK44) + '<span>搜标题、摘要或来源</span></div>'
        '<div style="display: flex; align-items: center; gap: 8px; height: 40px; width: 280px; padding: 0 12px; border: 1px solid #000000; border-radius: 8px; box-sizing: border-box; font-size: 14px; box-shadow: 0 0 0 3px ' + BORDER + ';">' + icon('search', 18, INK64) + '<span>终端 工具</span></div>'
        '</div>')
    # 标签页与筛选
    tabs = sec('标签页与筛选', '标签页用文字加下划线；筛选用胶囊，是唯一的胶囊家族',
        '<div style="display: flex; flex-direction: column; gap: 20px; width: 720px;">' + text_tabs('全部', ['全部', '日刊', '周刊'])
        + '<div style="display: flex; gap: 8px; flex-wrap: wrap;">' + pill('Hacker News') + pill('阮一峰周刊', selected=True) + pill('近 30 天', icon_right='chevron-down') + '</div></div>')
    # 状态
    dot_ok = '<span style="width: 8px; height: 8px; border-radius: 50%; background: #000000; display: inline-block;"></span>'
    dot_empty = '<span style="width: 8px; height: 8px; border-radius: 50%; border: 1.5px solid ' + INK44 + '; box-sizing: border-box; display: inline-block;"></span>'
    dot_missing = '<span style="width: 8px; height: 8px; border-radius: 50%; border: 1.5px dashed ' + INK44 + '; box-sizing: border-box; display: inline-block;"></span>'
    states = sec('状态', '语义色只保留给失败与警告，其余靠形状',
        '<div style="display: flex; flex-direction: column; gap: 20px;">'
        '<div style="display: flex; gap: 24px;">'
        '<span style="display: inline-flex; align-items: center; gap: 8px;">' + dot_ok + '<span style="font-size: 14px;">已发布</span></span>'
        '<span style="display: inline-flex; align-items: center; gap: 8px;">' + dot_empty + '<span style="font-size: 14px;">空刊</span></span>'
        '<span style="display: inline-flex; align-items: center; gap: 8px;">' + dot_missing + '<span style="font-size: 14px;">未生成</span></span></div>'
        '<div style="display: flex; align-items: center; gap: 10px;">' + icon('triangle-alert', 18, WARN) + '<span style="font-size: 15px; color: ' + WARN + ';">今日抓取失败</span>' + mono('已通知管理员', INK44) + '</div>'
        '<div style="display: flex; align-items: center; gap: 10px;">' + icon('clock', 18, INK64) + '<span style="font-size: 15px; color: ' + INK64 + ';">今日无新内容</span></div>'
        '<div style="display: flex; flex-direction: column; gap: 12px; padding: 32px; border: 1px dashed ' + BORDER_STRONG + '; border-radius: 8px; width: 480px; box-sizing: border-box;">'
        '<span style="font-size: 16px;">没有「终端 工具」的结果，试试更短的词或放宽筛选</span><div>' + button('清除筛选', 'outline') + '</div></div>'
        '</div>')
    # 列表行
    listrow = sec('列表行', '序号 28 · 间距 16 · 行内 6 · 行间 20 · 不加边框',
        '<div style="width: 420px; display: flex; flex-direction: column; gap: 20px;">' + row('01', 'Show HN: A terminal log viewer written in Rust', '▲ 312 · 145 评论 · 5h')
        + row('02', 'nine-tails/termlog', 'Rust · ★ 2.4k · +288', 'Structured log viewer for the terminal') + '</div>')
    # 图标
    names = ['search', 'menu', 'x', 'chevron-left', 'chevron-right', 'chevron-down', 'arrow-right', 'arrow-up-right', 'calendar', 'book-open', 'archive', 'clock', 'user', 'settings', 'shield', 'check', 'triangle-alert', 'refresh-cw', 'log-out']
    icons_html = ''.join('<div style="display: flex; flex-direction: column; align-items: flex-start; gap: 8px; width: 108px;">' + icon(n, 24, INK64) + mono(n, INK44, 11) + '</div>' for n in names)
    icons = sec('图标', 'Lucide 描边图标，1.75 描边，64% 墨色；实现时经 morphicons 渲染，菜单与关闭、搜索与关闭、展开箭头之间做形变过渡',
        '<div style="display: flex; gap: 8px; flex-wrap: wrap;">' + icons_html + '</div>')
    # 间距
    spacing = sec('间距', '8 节律，4 微调',
        '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; width: 900px;">'
        '<div style="display: flex; flex-direction: column; gap: 6px;"><span style="font-size: 14px; font-weight: 500;">页面</span>' + mono('桌面边距 64 · 移动 24', INK64) + mono('期头上 56 下 40', INK64) + mono('章节间 96', INK64) + '</div>'
        '<div style="display: flex; flex-direction: column; gap: 6px;"><span style="font-size: 14px; font-weight: 500;">栏与列表</span>' + mono('栏间 56', INK64) + mono('记录间 20 · 记录内 6', INK64) + mono('长列表交替底色 3%', INK64) + '</div>'
        '<div style="display: flex; flex-direction: column; gap: 6px;"><span style="font-size: 14px; font-weight: 500;">控件</span>' + mono('桌面高 40 · 移动 44', INK64) + mono('圆角 8 · 胶囊 999', INK64) + mono('相邻控件间 8', INK64) + '</div>'
        '</div>')
    header = '<div style="padding: 56px 64px 40px 64px; display: flex; flex-direction: column; gap: 8px;"><h1 style="margin: 0; font-size: 28px; font-weight: 500;">组件与规范</h1>' + mono('对应 shadcn/ui 的 Button、Input、Tabs、Badge、Separator 结构；数值为实现时的令牌', INK44) + '</div>\n'
    body = '<div style="padding: 0 64px 40px 64px; display: flex; flex-direction: column;">' + colors + fonts + buttons + inputs + tabs + states + listrow + icons + spacing + '</div>\n'
    return document(header + body, 1440, 2560)
