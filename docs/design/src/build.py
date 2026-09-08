"""生成 lowpass 设计画板。用法：python3 docs/design/src/build.py <输出目录>"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pages_reader as R, pages_weekly as W, pages_other as O, pages_warm as T, pages_bright as B, pages_minimal as M

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
design_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

pages = {
    # 第四轮：六种版面结构（Main 即方向 1 海报报头）
    'Main.dc.html': M.poster(), 'MinSplit.dc.html': M.split(), 'MinCover.dc.html': M.cover(),
    'MinBento.dc.html': M.bento(), 'MinRail.dc.html': M.rail(), 'MinJournal.dc.html': M.journal(),
    # 第三轮：六个明亮方向（已否，存档）
    'BrightSunrise.dc.html': B.sunrise(), 'BrightSources.dc.html': B.sources(), 'BrightCitrus.dc.html': B.citrus(),
    'BrightPastel.dc.html': B.pastel(), 'BrightYellow.dc.html': B.yellow(), 'BrightGreen.dc.html': B.green(),
    # 第二轮：暖色方向（已否，存档）
    'TerracottaDaily.dc.html': T.terracotta(), 'RisoDaily.dc.html': T.riso(), 'ClaudeWarmDaily.dc.html': T.claude_warm(),
    # 第一轮全套：斯堪的纳维亚（已否，存档）
    'Login.dc.html': R.login(), 'Home.dc.html': R.home(), 'ScandiDaily.dc.html': R.daily(),
    'DailyMobile.dc.html': R.daily_mobile(), 'DailyArchive.dc.html': R.daily_archive(),
    'Weekly.dc.html': W.weekly(), 'WeeklyMobile.dc.html': W.weekly_mobile(), 'WeeklyArchive.dc.html': W.weekly_archive(),
    'Search.dc.html': O.search(), 'Settings.dc.html': O.settings(), 'Components.dc.html': O.components(),
}
for name, html in pages.items():
    with open(os.path.join(out, name), 'w', encoding='utf-8') as f:
        f.write(html)
for name in ['DirectionA.dc.html', 'DirectionB.dc.html', 'DirectionC.dc.html']:
    shutil.copy(os.path.join(design_dir, name), os.path.join(out, name))

P1, P2, P3, P4, P5 = 'page-1', 'page-2', 'page-3', 'page-4', 'page-5'
H, HB = 2000, 1450
canvas = {
    'pages': [{'id': P1, 'name': '版面结构（第四轮）'}, {'id': P2, 'name': '明亮配色（第三轮，已否）'}, {'id': P3, 'name': '暖色（第二轮，已否）'}, {'id': P4, 'name': '斯堪的纳维亚（已否）'}, {'id': P5, 'name': '早期方向（存档）'}],
    'artboards': [
        {'file': 'Main.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': H, 'title': '方向 1 · 海报报头（Main）', 'page': P1},
        {'file': 'MinSplit.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': H, 'title': '方向 2 · 左栏固定', 'page': P1},
        {'file': 'MinCover.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': H, 'title': '方向 3 · 封面加目录', 'page': P1},
        {'file': 'MinBento.dc.html', 'x': 0, 'y': 2300, 'w': 1440, 'h': H, 'title': '方向 4 · 便当格', 'page': P1},
        {'file': 'MinRail.dc.html', 'x': 1560, 'y': 2300, 'w': 1440, 'h': H, 'title': '方向 5 · 早间轴', 'page': P1},
        {'file': 'MinJournal.dc.html', 'x': 3120, 'y': 2300, 'w': 1440, 'h': H, 'title': '方向 6 · 手账', 'page': P1},
        {'file': 'BrightSunrise.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': HB, 'title': '晨光（已否）', 'page': P2},
        {'file': 'BrightSources.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': HB, 'title': '来源分色（已否）', 'page': P2},
        {'file': 'BrightCitrus.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': HB, 'title': '柑橘渐变（已否）', 'page': P2},
        {'file': 'BrightPastel.dc.html', 'x': 0, 'y': 1760, 'w': 1440, 'h': HB, 'title': '柔和粉彩（已否）', 'page': P2},
        {'file': 'BrightYellow.dc.html', 'x': 1560, 'y': 1760, 'w': 1440, 'h': HB, 'title': '阳光黄（已否）', 'page': P2},
        {'file': 'BrightGreen.dc.html', 'x': 3120, 'y': 1760, 'w': 1440, 'h': HB, 'title': '清新绿（已否）', 'page': P2},
        {'file': 'TerracottaDaily.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': HB, 'title': 'Terracotta（已否）', 'page': P3},
        {'file': 'RisoDaily.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': HB, 'title': 'Riso（已否）', 'page': P3},
        {'file': 'ClaudeWarmDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': HB, 'title': 'Claude 暖编辑（已否）', 'page': P3},
        {'file': 'Login.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 900, 'title': '登录', 'page': P4},
        {'file': 'Home.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1240, 'title': '首页', 'page': P4},
        {'file': 'ScandiDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1280, 'title': '日刊详情', 'page': P4},
        {'file': 'DailyMobile.dc.html', 'x': 0, 'y': 1400, 'w': 390, 'h': 1160, 'title': '日刊详情 · 手机', 'page': P4},
        {'file': 'DailyArchive.dc.html', 'x': 560, 'y': 1400, 'w': 1440, 'h': 1000, 'title': '日刊归档', 'page': P4},
        {'file': 'Weekly.dc.html', 'x': 2120, 'y': 1400, 'w': 1440, 'h': 1900, 'title': '周刊详情', 'page': P4},
        {'file': 'WeeklyMobile.dc.html', 'x': 0, 'y': 3440, 'w': 390, 'h': 1160, 'title': '周刊详情 · 手机', 'page': P4},
        {'file': 'WeeklyArchive.dc.html', 'x': 560, 'y': 3440, 'w': 1440, 'h': 900, 'title': '周刊归档', 'page': P4},
        {'file': 'Search.dc.html', 'x': 2120, 'y': 3440, 'w': 1440, 'h': 1200, 'title': '搜索', 'page': P4},
        {'file': 'Settings.dc.html', 'x': 0, 'y': 4800, 'w': 1440, 'h': 760, 'title': '设置', 'page': P4},
        {'file': 'Components.dc.html', 'x': 1560, 'y': 4800, 'w': 1440, 'h': 2560, 'title': '组件与规范', 'page': P4},
        {'file': 'DirectionA.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 A · 刊物（存档）', 'page': P5},
        {'file': 'DirectionB.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 B · 工具（存档）', 'page': P5},
        {'file': 'DirectionC.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 C · 杂志（存档）', 'page': P5},
    ],
    'annotations': [
        {'id': 'm1', 'x': 0, 'y': -240, 'w': 560, 'page': P1, 'text': '方向 1 · 海报报头\n主意：把日期当海报。168px 的文楷日期占左侧五栏，右侧是目录式的来源索引，列表区用一道墨色粗线切开。\n取舍：最有"刊"的仪式感；首屏给日期让了位，内容起点靠下。'},
        {'id': 'm2', 'x': 1560, 'y': -240, 'w': 560, 'page': P1, 'text': '方向 2 · 左栏固定\n主意：像一个应用。左侧 420px 淡杏色面板放日期、来源导航与周刊入口并固定，右侧是单栏阅读流，大序号、大标题。\n取舍：阅读专注、切换来源快；单栏依次展开三个来源，横向对比弱。'},
        {'id': 'm3', 'x': 3120, 'y': -240, 'w': 560, 'page': P1, 'text': '方向 3 · 封面加目录\n主意：像一本杂志。先是一块圆角封面：日期加"今日看点"三行导语，每源取一条；再是目录式三栏。\n取舍：有"打开一期"的层次，导语给了编辑感；封面占高约 400px。'},
        {'id': 'm4', 'x': 0, 'y': 2060, 'w': 560, 'page': P1, 'text': '方向 4 · 便当格\n主意：不等宽的拼盘。日期格、"67 条"数字格、周刊格与三个来源格，圆角 20，只用两种底色。\n取舍：一屏全览、有节奏；格子多了要靠字号压秩序。'},
        {'id': 'm5', 'x': 1560, 'y': 2060, 'w': 560, 'page': P1, 'text': '方向 5 · 早间轴\n主意：把一期当作一段时间。居中单栏，左侧一条轴从"06:12 装订"到"明早 06:00 下一期"，太阳点是唯一的渐变。\n取舍：叙事感强、最像"早读"；单栏纵向长，一屏看不全。'},
        {'id': 'm6', 'x': 3120, 'y': 2060, 'w': 560, 'page': P1, 'text': '方向 6 · 手账\n主意：一页笔记。文楷同时用于日期与板块名，点线分隔像横格纸，元数据放到右侧页边像批注，杏橙圆点做项目符号。\n取舍：最有温度、最个人；文楷用量超出"只做期头"的原定范围。'},
        {'id': 'keep-note', 'x': 3120, 'y': 4400, 'w': 560, 'page': P1, 'text': '六稿统一：白底，唯一点缀色杏橙 #F26B3A（文字用深一档 #B8461C），Instrument Sans 配 Noto Sans SC，元数据 Maple Mono，期头文楷。这样比的是版面结构。Main 当前是方向 1。'},
        {'id': 'bright-note', 'x': 0, 'y': -240, 'w': 560, 'page': P2, 'text': '第三轮六稿，已否：结构相同只换配色，缺设计感。'},
        {'id': 'warm-note', 'x': 0, 'y': -240, 'w': 560, 'page': P3, 'text': '第二轮三稿，已否：1 与 3 偏土，2 偏花。'},
        {'id': 'scandi-note', 'x': 0, 'y': -240, 'w': 560, 'page': P4, 'text': '斯堪的纳维亚全套，已否（太冷、无色）。保留供对照页面结构与组件规范。'},
        {'id': 'archive-note', 'x': 0, 'y': -200, 'w': 520, 'page': P5, 'text': '第一轮的三个方向草稿，仅存档参考。'},
    ],
    'launch': {'view': 'canvas', 'page': P1},
}
with open(os.path.join(out, 'canvas.json'), 'w', encoding='utf-8') as f:
    json.dump(canvas, f, ensure_ascii=False, indent=2)
print('built', len(pages), 'pages +3 archived ->', out)
