"""生成 lowpass 设计画板。用法：python3 docs/design/src/build.py <输出目录>"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pages_reader as R, pages_weekly as W, pages_other as O, pages_warm as T, pages_bright as B, pages_minimal as M, pages_paper as P, pages_press as X, pages_front2 as F

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
design_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

pages = {
    # 第八轮：纵向有重心
    'Main.dc.html': F.front2(), 'FrontStates.dc.html': F.front2_states(), 'FrontMobile.dc.html': F.front2_mobile(),
    # 第七轮：三栏并列（已否，存档）
    'FrontColumns.dc.html': X.front(),
    # 第六轮：完整一期 67 条（存档，对照）
    'PressFull.dc.html': X.press(),
    # 第五轮：纸报初稿（存档）
    'PaperBeige.dc.html': P.paper_beige(), 'PaperLight.dc.html': P.paper_light(),
    # 第四轮：六种版面结构（已否，存档）
    'MinPoster.dc.html': M.poster(), 'MinSplit.dc.html': M.split(), 'MinCover.dc.html': M.cover(),
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

P1, P2, P3, P4, P5, P6, P7 = 'page-1', 'page-2', 'page-3', 'page-4', 'page-5', 'page-6', 'page-7'
HP, H, HB = 2300, 2000, 1450
canvas = {
    'pages': [{'id': P1, 'name': '纸报 · 完整一期（第六轮）'}, {'id': P7, 'name': '纸报初稿（第五轮）'}, {'id': P2, 'name': '版面结构（第四轮，已否）'}, {'id': P3, 'name': '明亮配色（第三轮，已否）'}, {'id': P4, 'name': '暖色（第二轮，已否）'}, {'id': P5, 'name': '斯堪的纳维亚（已否）'}, {'id': P6, 'name': '早期方向（存档）'}],
    'artboards': [
        {'file': 'Main.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 2700, 'title': '日刊 · 纵向有重心（Main）', 'page': P1},
        {'file': 'FrontStates.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1850, 'title': '日刊 · 状态：延迟、抓取失败、无新内容', 'page': P1},
        {'file': 'FrontMobile.dc.html', 'x': 3120, 'y': 0, 'w': 390, 'h': 4400, 'title': '日刊 · 手机', 'page': P1},
        {'file': 'FrontColumns.dc.html', 'x': 4680, 'y': 0, 'w': 1440, 'h': 2500, 'title': '三栏并列（已否）', 'page': P7},
        {'file': 'PressFull.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 4000, 'title': '对照 · 完整一期 67 条（已否）', 'page': P7},
        {'file': 'PaperBeige.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': HP, 'title': '初稿 · 纸色忠实参考', 'page': P7},
        {'file': 'PaperLight.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': HP, 'title': '初稿 · 浅纸色（已选）', 'page': P7},
        {'file': 'MinPoster.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': H, 'title': '海报报头（已否）', 'page': P2},
        {'file': 'MinSplit.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': H, 'title': '左栏固定（已否）', 'page': P2},
        {'file': 'MinCover.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': H, 'title': '封面加目录（已否）', 'page': P2},
        {'file': 'MinBento.dc.html', 'x': 0, 'y': 2300, 'w': 1440, 'h': H, 'title': '便当格（已否）', 'page': P2},
        {'file': 'MinRail.dc.html', 'x': 1560, 'y': 2300, 'w': 1440, 'h': H, 'title': '早间轴（已否）', 'page': P2},
        {'file': 'MinJournal.dc.html', 'x': 3120, 'y': 2300, 'w': 1440, 'h': H, 'title': '手账（已否）', 'page': P2},
        {'file': 'BrightSunrise.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': HB, 'title': '晨光（已否）', 'page': P3},
        {'file': 'BrightSources.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': HB, 'title': '来源分色（已否）', 'page': P3},
        {'file': 'BrightCitrus.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': HB, 'title': '柑橘渐变（已否）', 'page': P3},
        {'file': 'BrightPastel.dc.html', 'x': 0, 'y': 1760, 'w': 1440, 'h': HB, 'title': '柔和粉彩（已否）', 'page': P3},
        {'file': 'BrightYellow.dc.html', 'x': 1560, 'y': 1760, 'w': 1440, 'h': HB, 'title': '阳光黄（已否）', 'page': P3},
        {'file': 'BrightGreen.dc.html', 'x': 3120, 'y': 1760, 'w': 1440, 'h': HB, 'title': '清新绿（已否）', 'page': P3},
        {'file': 'TerracottaDaily.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': HB, 'title': 'Terracotta（已否）', 'page': P4},
        {'file': 'RisoDaily.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': HB, 'title': 'Riso（已否）', 'page': P4},
        {'file': 'ClaudeWarmDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': HB, 'title': 'Claude 暖编辑（已否）', 'page': P4},
        {'file': 'Login.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 900, 'title': '登录', 'page': P5},
        {'file': 'Home.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1240, 'title': '首页', 'page': P5},
        {'file': 'ScandiDaily.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1280, 'title': '日刊详情', 'page': P5},
        {'file': 'DailyMobile.dc.html', 'x': 0, 'y': 1400, 'w': 390, 'h': 1160, 'title': '日刊详情 · 手机', 'page': P5},
        {'file': 'DailyArchive.dc.html', 'x': 560, 'y': 1400, 'w': 1440, 'h': 1000, 'title': '日刊归档', 'page': P5},
        {'file': 'Weekly.dc.html', 'x': 2120, 'y': 1400, 'w': 1440, 'h': 1900, 'title': '周刊详情', 'page': P5},
        {'file': 'WeeklyMobile.dc.html', 'x': 0, 'y': 3440, 'w': 390, 'h': 1160, 'title': '周刊详情 · 手机', 'page': P5},
        {'file': 'WeeklyArchive.dc.html', 'x': 560, 'y': 3440, 'w': 1440, 'h': 900, 'title': '周刊归档', 'page': P5},
        {'file': 'Search.dc.html', 'x': 2120, 'y': 3440, 'w': 1440, 'h': 1200, 'title': '搜索', 'page': P5},
        {'file': 'Settings.dc.html', 'x': 0, 'y': 4800, 'w': 1440, 'h': 760, 'title': '设置', 'page': P5},
        {'file': 'Components.dc.html', 'x': 1560, 'y': 4800, 'w': 1440, 'h': 2560, 'title': '组件与规范', 'page': P5},
        {'file': 'DirectionA.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 A · 刊物（存档）', 'page': P6},
        {'file': 'DirectionB.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 B · 工具（存档）', 'page': P6},
        {'file': 'DirectionC.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 C · 杂志（存档）', 'page': P6},
    ],
    'annotations': [
        {'id': 'x1', 'x': 0, 'y': -300, 'w': 720, 'page': P1, 'text': '第八轮 · 按评审修订清单\n重心：不再三栏并列。每个来源一节，头条横贯整节做重心，第 2 到 10 条在其下分两栏；一屏只有一个焦点，自上而下阅读。\n首屏：报头缩成 80px 一行式黑带，日期与发布信息同一行，右侧前后期与归档；数据带与索引条删除，内容在 250px 内出现。\n减噪：插图缩为节名旁 44px 的图标；绿徽章只给前三名；序号降为等宽灰字；字体收敛为四个家族：Bodoni、Newsreader（中文回退 Noto Serif SC）、文楷、Maple Mono。\n可点性：标题统一 30% 墨色细下划线，悬停变实；栏尾外链措辞统一。\n文案：读者页面上没有任何非数据文字。每个元素对应一条真实字段：报耳的日期、发布时间与条目数；数据带里的来源数、条目数、抓取用时、昨日条数（来自抓取记录）；索引条里的三个来源与计数（滚动时吸顶，点击跳到该栏）；列表里的序号、标题、分数、评论、时间、语言、star、今日新增、作者、摘要。\n易读：正文 17px Newsreader 400，行高 1.35 以上；次级墨色 #55504B 在浅纸上对比度约 6:1；大写只用于拉丁栏目标题；标题整行可点，悬停下划线。'},
        {'id': 'x2', 'x': 1560, 'y': -300, 'w': 640, 'page': P1, 'text': '状态稿与手机稿\n中间一稿展示三种状态：期头带“延迟生成于 07:05”标签；Hacker News 一节抓取失败，保留节头，正文说明上次成功时间与自动补齐；GitHub 一节今日无新内容。\n右侧是 390 宽手机版：56px 报头，日期缩小，前后期按钮 44 高，每节头条放大后接列表。\n\n插图\n与参考相同的手法：墨线木刻感、细线排线做阴影、装在 1px 框里并配大写图注，纸色留白，一点鼠尾草绿。四幅全部原创：报头旁的"低通日出"（噪声波经滤波器变成平滑波，太阳从地平线升起）、Hacker News 的"讨论"（两个对话气泡与向上箭头）、GitHub 的"分支"（提交节点与合流的枝，顶端一颗星）、Hackaday 的"焊接"（烙铁、烟和一枚芯片），页脚一枚 LP 邮戳。\n没有沿用参考站的刺猬角色和作品照片。若你希望有一个自己的角色形象，另起一轮单独定。'},
        {'id': 'p1', 'x': 0, 'y': -300, 'w': 640, 'page': P7, 'text': '纸报初稿 · 参考 niccolomiranda.com 的气质迁移\n迁移了什么：深色桌面 #1D1D1B 上一张有纸纹的纸；1px 墨线做栏框与表格；巨型高对比衬线报头（Bodoni Moda 替代 Canopee）；轻衬线正文与斜体导语（Newsreader 替代 Editorial New）；窄体大写栏目标题（Oswald 替代 Domaine Display Condensed）；一点鼠尾草绿 #96B59F 做徽章。\n没有搬的：它的标志、插画、作品图与文案。\n日刊本来就是一份报纸：报耳放日期与导航，报头下是标语，头条加双栏编号，GitHub 做成表格，Hackaday 做成带编号方块的三栏卡。文楷用在报耳日期与标语，元数据 Maple Mono。'},
        {'id': 'p2', 'x': 1560, 'y': -300, 'w': 560, 'page': P7, 'text': '浅纸色变体（已选）\n结构完全相同，纸色从 #CDC6BE 提到 #E8E3DA。给你比较"忠实参考"与"更亮一点"哪种更舒服。'},
        {'id': 'min-note', 'x': 0, 'y': -240, 'w': 560, 'page': P2, 'text': '第四轮六稿，已否：仍不够有设计感。'},
        {'id': 'bright-note', 'x': 0, 'y': -240, 'w': 560, 'page': P3, 'text': '第三轮六稿，已否：结构相同只换配色。'},
        {'id': 'warm-note', 'x': 0, 'y': -240, 'w': 560, 'page': P4, 'text': '第二轮三稿，已否：1 与 3 偏土，2 偏花。'},
        {'id': 'scandi-note', 'x': 0, 'y': -240, 'w': 560, 'page': P5, 'text': '斯堪的纳维亚全套，已否（太冷、无色）。保留供对照页面结构与组件规范。'},
        {'id': 'archive-note', 'x': 0, 'y': -200, 'w': 520, 'page': P6, 'text': '第一轮的三个方向草稿，仅存档参考。'},
    ],
    'launch': {'view': 'canvas', 'page': P1},
}
with open(os.path.join(out, 'canvas.json'), 'w', encoding='utf-8') as f:
    json.dump(canvas, f, ensure_ascii=False, indent=2)
print('built', len(pages), 'pages +3 archived ->', out)
