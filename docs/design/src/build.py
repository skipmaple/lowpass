"""生成 lowpass 设计画板。用法：python3 docs/design/src/build.py <输出目录>"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pages_reader as R, pages_weekly as W, pages_other as O, pages_warm as T

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
design_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

terra = T.terracotta()
pages = {
    # 第二轮：暖色方向
    'TerracottaDaily.dc.html': terra, 'RisoDaily.dc.html': T.riso(), 'ClaudeWarmDaily.dc.html': T.claude_warm(),
    'Main.dc.html': terra,
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

P1, P2, P3 = 'page-1', 'page-2', 'page-3'
canvas = {
    'pages': [{'id': P1, 'name': '暖色方向（第二轮）'}, {'id': P2, 'name': '斯堪的纳维亚（已否）'}, {'id': P3, 'name': '早期方向（存档）'}],
    'artboards': [
        {'file': 'TerracottaDaily.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 1450, 'title': '方向 1 · Terracotta', 'page': P1},
        {'file': 'RisoDaily.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1450, 'title': '方向 2 · Riso', 'page': P1},
        {'file': 'ClaudeWarmDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1450, 'title': '方向 3 · Claude 暖编辑', 'page': P1},
        {'file': 'Main.dc.html', 'x': 0, 'y': 1620, 'w': 1440, 'h': 1450, 'title': 'Main · 领先候选（同 Terracotta）', 'page': P1},
        {'file': 'Login.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 900, 'title': '登录', 'page': P2},
        {'file': 'Home.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1240, 'title': '首页', 'page': P2},
        {'file': 'ScandiDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1280, 'title': '日刊详情', 'page': P2},
        {'file': 'DailyMobile.dc.html', 'x': 0, 'y': 1400, 'w': 390, 'h': 1160, 'title': '日刊详情 · 手机', 'page': P2},
        {'file': 'DailyArchive.dc.html', 'x': 560, 'y': 1400, 'w': 1440, 'h': 1000, 'title': '日刊归档', 'page': P2},
        {'file': 'Weekly.dc.html', 'x': 2120, 'y': 1400, 'w': 1440, 'h': 1900, 'title': '周刊详情', 'page': P2},
        {'file': 'WeeklyMobile.dc.html', 'x': 0, 'y': 3440, 'w': 390, 'h': 1160, 'title': '周刊详情 · 手机', 'page': P2},
        {'file': 'WeeklyArchive.dc.html', 'x': 560, 'y': 3440, 'w': 1440, 'h': 900, 'title': '周刊归档', 'page': P2},
        {'file': 'Search.dc.html', 'x': 2120, 'y': 3440, 'w': 1440, 'h': 1200, 'title': '搜索', 'page': P2},
        {'file': 'Settings.dc.html', 'x': 0, 'y': 4800, 'w': 1440, 'h': 760, 'title': '设置', 'page': P2},
        {'file': 'Components.dc.html', 'x': 1560, 'y': 4800, 'w': 1440, 'h': 2560, 'title': '组件与规范', 'page': P2},
        {'file': 'DirectionA.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 A · 刊物（存档）', 'page': P3},
        {'file': 'DirectionB.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 B · 工具（存档）', 'page': P3},
        {'file': 'DirectionC.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 C · 杂志（存档）', 'page': P3},
    ],
    'annotations': [
        {'id': 'terra-note', 'x': 0, 'y': -260, 'w': 560, 'page': P1,
         'text': '方向 1 · Terracotta（bergside/awesome-design-skills）\n奶油底 #F3E9D8，白色大版面承载三栏，陶土 #C56A3C 只做点缀：星期、序号、栏目名、更多链接、期头下的一道线。标题 DM Serif Display，界面字 Noto Sans SC。\n取舍：暖而稳，最接近"刊"；色彩不多，靓丽度靠陶土一色。'},
        {'id': 'riso-note', 'x': 1560, 'y': -260, 'w': 560, 'page': P1,
         'text': '方向 2 · Riso（bergside/awesome-design-skills）\n暖白纸底 #FAF6EE，荧光粉 #F237A1 与深蓝 #2C40A7 双色印刷：粉色偏移阴影、蓝色栏头色块、点状网纹，期头日期带套印错位。字体 Space Grotesk。\n取舍：最阳光、最有个性；页面元素多时会显得花，需要克制使用粉色。'},
        {'id': 'claude-note', 'x': 3120, 'y': -260, 'w': 560, 'page': P1,
         'text': '方向 3 · Claude 暖编辑（VoltAgent/awesome-design-md 的 claude DESIGN.md）\n画布 #faf9f5 奶油而非纯白，三栏是 #efe9de 的色块卡片，靠色块分层不用阴影；珊瑚 #cc785c 只给每栏的"其余 N 条"这一个操作；底部一条深色带做节奏。标题 Source Serif 4，界面字 Inter。\n取舍：暖、人文、克制，品牌启发系统只取逻辑不照搬。'},
        {'id': 'keep-note', 'x': 1560, 'y': 1620, 'w': 560, 'page': P1,
         'text': '三稿共用：期头日期用霞鹜文楷，元数据用 Maple Mono，图标为 Lucide。条目全是虚构样例。\nMain 暂放领先候选 Terracotta，选定后换成最终设计并补齐其余页面。'},
        {'id': 'scandi-note', 'x': 0, 'y': -240, 'w': 560, 'page': P2, 'text': '斯堪的纳维亚全套，已被否（太冷、无色）。保留供对照页面结构与组件规范。'},
        {'id': 'archive-note', 'x': 0, 'y': -200, 'w': 520, 'page': P3, 'text': '第一轮的三个方向草稿，仅存档参考。'},
    ],
    'launch': {'view': 'canvas', 'page': P1},
}
with open(os.path.join(out, 'canvas.json'), 'w', encoding='utf-8') as f:
    json.dump(canvas, f, ensure_ascii=False, indent=2)
print('built', len(pages), 'pages +3 archived ->', out)
