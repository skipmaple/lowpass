"""生成 lowpass 设计画板。用法：python3 docs/design/src/build.py <输出目录>"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pages_reader as R, pages_weekly as W, pages_other as O, pages_warm as T, pages_bright as B

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
design_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

pages = {
    # 第三轮：六个明亮方向（Main 即方向 1 晨光）
    'Main.dc.html': B.sunrise(), 'BrightSources.dc.html': B.sources(), 'BrightCitrus.dc.html': B.citrus(),
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

P1, P2, P3, P4 = 'page-1', 'page-2', 'page-3', 'page-4'
H = 1450
canvas = {
    'pages': [{'id': P1, 'name': '明亮方向（第三轮）'}, {'id': P2, 'name': '暖色方向（第二轮，已否）'}, {'id': P3, 'name': '斯堪的纳维亚（已否）'}, {'id': P4, 'name': '早期方向（存档）'}],
    'artboards': [
        {'file': 'Main.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': H, 'title': '方向 1 · 晨光（Main）', 'page': P1},
        {'file': 'BrightSources.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': H, 'title': '方向 2 · 来源分色', 'page': P1},
        {'file': 'BrightCitrus.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': H, 'title': '方向 3 · 柑橘渐变', 'page': P1},
        {'file': 'BrightPastel.dc.html', 'x': 0, 'y': 1760, 'w': 1440, 'h': H, 'title': '方向 4 · 柔和粉彩', 'page': P1},
        {'file': 'BrightYellow.dc.html', 'x': 1560, 'y': 1760, 'w': 1440, 'h': H, 'title': '方向 5 · 阳光黄', 'page': P1},
        {'file': 'BrightGreen.dc.html', 'x': 3120, 'y': 1760, 'w': 1440, 'h': H, 'title': '方向 6 · 清新绿', 'page': P1},
        {'file': 'TerracottaDaily.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': H, 'title': 'Terracotta（已否）', 'page': P2},
        {'file': 'RisoDaily.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': H, 'title': 'Riso（已否）', 'page': P2},
        {'file': 'ClaudeWarmDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': H, 'title': 'Claude 暖编辑（已否）', 'page': P2},
        {'file': 'Login.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 900, 'title': '登录', 'page': P3},
        {'file': 'Home.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1240, 'title': '首页', 'page': P3},
        {'file': 'ScandiDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1280, 'title': '日刊详情', 'page': P3},
        {'file': 'DailyMobile.dc.html', 'x': 0, 'y': 1400, 'w': 390, 'h': 1160, 'title': '日刊详情 · 手机', 'page': P3},
        {'file': 'DailyArchive.dc.html', 'x': 560, 'y': 1400, 'w': 1440, 'h': 1000, 'title': '日刊归档', 'page': P3},
        {'file': 'Weekly.dc.html', 'x': 2120, 'y': 1400, 'w': 1440, 'h': 1900, 'title': '周刊详情', 'page': P3},
        {'file': 'WeeklyMobile.dc.html', 'x': 0, 'y': 3440, 'w': 390, 'h': 1160, 'title': '周刊详情 · 手机', 'page': P3},
        {'file': 'WeeklyArchive.dc.html', 'x': 560, 'y': 3440, 'w': 1440, 'h': 900, 'title': '周刊归档', 'page': P3},
        {'file': 'Search.dc.html', 'x': 2120, 'y': 3440, 'w': 1440, 'h': 1200, 'title': '搜索', 'page': P3},
        {'file': 'Settings.dc.html', 'x': 0, 'y': 4800, 'w': 1440, 'h': 760, 'title': '设置', 'page': P3},
        {'file': 'Components.dc.html', 'x': 1560, 'y': 4800, 'w': 1440, 'h': 2560, 'title': '组件与规范', 'page': P3},
        {'file': 'DirectionA.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 A · 刊物（存档）', 'page': P4},
        {'file': 'DirectionB.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 B · 工具（存档）', 'page': P4},
        {'file': 'DirectionC.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 C · 杂志（存档）', 'page': P4},
    ],
    'annotations': [
        {'id': 'n1', 'x': 0, 'y': -240, 'w': 560, 'page': P1, 'text': '方向 1 · 晨光\n轴：白底上只有一个日出橙。橙色只出现在星期、序号、导航指示、栏目上的一小段色条和"其余"链接；圆润的 Manrope，大留白。\n取舍：最干净、最耐看；"暖"是克制的，靠一色撑。'},
        {'id': 'n2', 'x': 1560, 'y': -240, 'w': 560, 'page': P1, 'text': '方向 2 · 来源分色\n轴：颜色有功能。三个来源各一个明亮色调的栏头：Hacker News 橙、GitHub 绿、Hackaday 黄，栏体保持白色。Plus Jakarta Sans。\n取舍：一眼分栏，色彩感强但有秩序；新增来源要再配一色。'},
        {'id': 'n3', 'x': 3120, 'y': -240, 'w': 560, 'page': P1, 'text': '方向 3 · 柑橘渐变\n轴：渐变只放在顶部横带，桃色到柠檬黄再到白；三张白卡片上浮进横带，带一点暖色阴影。Outfit。\n取舍：最"阳光"的第一眼；渐变要克制在横带内，否则容易俗。'},
        {'id': 'n4', 'x': 0, 'y': 1520, 'w': 560, 'page': P1, 'text': '方向 4 · 柔和粉彩\n轴：色块而非线条。桃、奶油黄、薄荷三块大圆角色块承载三栏，无边框无阴影，Nunito 圆体。\n取舍：最亲切、最"积极"；密度略低，色块多了容易像儿童产品，要靠字重压住。'},
        {'id': 'n5', 'x': 1560, 'y': 1520, 'w': 560, 'page': P1, 'text': '方向 5 · 阳光黄\n轴：一块明黄做期头底，黑字，栏目名用荧光笔式黄底高光，链接黄色下划线。Sora，图形感强。\n取舍：最有能量、最有记忆点；黄底大面积要控制，别处保持黑白。'},
        {'id': 'n6', 'x': 3120, 'y': 1520, 'w': 560, 'page': P1, 'text': '方向 6 · 清新绿\n轴：叶绿主色加一点太阳黄，白底，栏目名做成浅绿胶囊。Figtree。\n取舍：自然、有希望，和"过滤噪音"的产品理念相配；绿色在技术资讯产品里少见，辨识度高。'},
        {'id': 'keep-note', 'x': 3120, 'y': 3300, 'w': 560, 'page': P1, 'text': '六稿共用：期头日期用霞鹜文楷，元数据用 Maple Mono，图标 Lucide，条目为虚构样例。Main 当前是方向 1，选定后换成最终设计并补齐其余页面。'},
        {'id': 'warm-note', 'x': 0, 'y': -240, 'w': 560, 'page': P2, 'text': '第二轮三稿，已否：1 与 3 偏土，2 偏花。'},
        {'id': 'scandi-note', 'x': 0, 'y': -240, 'w': 560, 'page': P3, 'text': '斯堪的纳维亚全套，已否（太冷、无色）。保留供对照页面结构与组件规范。'},
        {'id': 'archive-note', 'x': 0, 'y': -200, 'w': 520, 'page': P4, 'text': '第一轮的三个方向草稿，仅存档参考。'},
    ],
    'launch': {'view': 'canvas', 'page': P1},
}
with open(os.path.join(out, 'canvas.json'), 'w', encoding='utf-8') as f:
    json.dump(canvas, f, ensure_ascii=False, indent=2)
print('built', len(pages), 'pages +3 archived ->', out)
