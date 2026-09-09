"""生成 lowpass 设计画板。用法：python3 docs/design/src/build.py <输出目录>"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pages_reader as R, pages_weekly as W, pages_other as O, pages_warm as T, pages_bright as B, pages_minimal as M, pages_paper as P, pages_press as X, pages_front2 as F, pages_front3 as G

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
design_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

pages = {
    # 第九轮：单栏、tab 切换、每条带推荐理由
    'Main.dc.html': G.front3(), 'FrontGitHub.dc.html': G.front3_gh(), 'FrontHackaday.dc.html': G.front3_had(),
    'FrontStates.dc.html': G.front3_states(), 'FrontMobile.dc.html': G.front3_mobile(),
    # 第八轮：头条放大分两栏（已否，存档）
    'FrontLead.dc.html': F.front2(),
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
    'pages': [{'id': P1, 'name': '日刊 · 当前稿（第九轮）'}, {'id': P7, 'name': '纸报初稿（第五轮）'}, {'id': P2, 'name': '版面结构（第四轮，已否）'}, {'id': P3, 'name': '明亮配色（第三轮，已否）'}, {'id': P4, 'name': '暖色（第二轮，已否）'}, {'id': P5, 'name': '斯堪的纳维亚（已否）'}, {'id': P6, 'name': '早期方向（存档）'}],
    'artboards': [
        {'file': 'Main.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 2000, 'title': '日刊 · Hacker News 标签（Main）', 'page': P1},
        {'file': 'FrontGitHub.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 2300, 'title': '日刊 · GitHub Trending 标签', 'page': P1},
        {'file': 'FrontHackaday.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 2300, 'title': '日刊 · Hackaday 标签', 'page': P1},
        {'file': 'FrontStates.dc.html', 'x': 4680, 'y': 0, 'w': 1440, 'h': 900, 'title': '日刊 · 状态：延迟、抓取失败、无新内容', 'page': P1},
        {'file': 'FrontMobile.dc.html', 'x': 6240, 'y': 0, 'w': 390, 'h': 2350, 'title': '日刊 · 手机', 'page': P1},
        {'file': 'FrontLead.dc.html', 'x': 6240, 'y': 0, 'w': 1440, 'h': 2700, 'title': '头条放大分两栏（已否）', 'page': P7},
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
        {'id': 'x1', 'x': 0, 'y': -320, 'w': 760, 'page': P1, 'text': '第九轮 · 产品负责人 2026-09-09 意见\n一栏：每个来源十条一致，不再放大头条，不再分两栏。\ntab 切换：三个来源做成并排的索引条，当前来源反白成墨色块，与报头黑带呼应，其余描边；每个索引条带小图标、来源名与一行说明。一次只看一个来源，页面从 2600px 缩到 1900px 以内。\n推荐理由：每条新增一段推荐理由（约 50 字，绿色细竖线标出）与一个兴趣标签（右侧描边小签），依据可配置的兴趣画像生成；相关度低时理由里直说。PRD 同步新增 D16。'},
        {'id': 'x2', 'x': 1560, 'y': -320, 'w': 700, 'page': P1, 'text': '三个标签各一稿：GitHub 条目多一行英文简介与语言、star、今日新增（前三名绿徽章）；Hackaday 条目多一行摘要与作者。\n状态稿：期头带延迟标签；失败的来源在索引条说明里直接写“抓取失败 · 上次成功时间”，内容区只留失败说明；无新内容的来源同样写在索引条上。\n手机稿：三个索引条等宽 44px 高，兴趣标签并入元数据行。'},
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
