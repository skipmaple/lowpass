"""生成 lowpass 设计画板。用法：python3 docs/design/src/build.py <输出目录>"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pages_reader as R, pages_weekly as W, pages_other as O

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
design_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

pages = {
    'Login.dc.html': R.login(), 'Home.dc.html': R.home(), 'Main.dc.html': R.daily(),
    'DailyMobile.dc.html': R.daily_mobile(), 'DailyArchive.dc.html': R.daily_archive(),
    'Weekly.dc.html': W.weekly(), 'WeeklyMobile.dc.html': W.weekly_mobile(), 'WeeklyArchive.dc.html': W.weekly_archive(),
    'Search.dc.html': O.search(), 'Settings.dc.html': O.settings(), 'Components.dc.html': O.components(),
}
for name, html in pages.items():
    with open(os.path.join(out, name), 'w', encoding='utf-8') as f:
        f.write(html)
for name in ['DirectionA.dc.html', 'DirectionB.dc.html', 'DirectionC.dc.html']:
    shutil.copy(os.path.join(design_dir, name), os.path.join(out, name))

canvas = {
    'pages': [{'id': 'page-1', 'name': '阅读页面'}, {'id': 'page-2', 'name': '组件与规范'}, {'id': 'page-3', 'name': '早期方向（存档）'}],
    'artboards': [
        {'file': 'Login.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 900, 'title': '登录', 'page': 'page-1'},
        {'file': 'Home.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1240, 'title': '首页', 'page': 'page-1'},
        {'file': 'Main.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1280, 'title': '日刊详情', 'page': 'page-1'},
        {'file': 'DailyMobile.dc.html', 'x': 0, 'y': 1400, 'w': 390, 'h': 1160, 'title': '日刊详情 · 手机', 'page': 'page-1'},
        {'file': 'DailyArchive.dc.html', 'x': 560, 'y': 1400, 'w': 1440, 'h': 1000, 'title': '日刊归档', 'page': 'page-1'},
        {'file': 'Weekly.dc.html', 'x': 2120, 'y': 1400, 'w': 1440, 'h': 1900, 'title': '周刊详情', 'page': 'page-1'},
        {'file': 'WeeklyMobile.dc.html', 'x': 0, 'y': 3440, 'w': 390, 'h': 1160, 'title': '周刊详情 · 手机', 'page': 'page-1'},
        {'file': 'WeeklyArchive.dc.html', 'x': 560, 'y': 3440, 'w': 1440, 'h': 900, 'title': '周刊归档', 'page': 'page-1'},
        {'file': 'Search.dc.html', 'x': 2120, 'y': 3440, 'w': 1440, 'h': 1200, 'title': '搜索', 'page': 'page-1'},
        {'file': 'Settings.dc.html', 'x': 0, 'y': 4800, 'w': 1440, 'h': 760, 'title': '设置', 'page': 'page-1'},
        {'file': 'Components.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 2560, 'title': '组件与规范', 'page': 'page-2'},
        {'file': 'DirectionA.dc.html', 'x': 0, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 A · 刊物（存档）', 'page': 'page-3'},
        {'file': 'DirectionB.dc.html', 'x': 1560, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 B · 工具（存档）', 'page': 'page-3'},
        {'file': 'DirectionC.dc.html', 'x': 3120, 'y': 0, 'w': 1440, 'h': 1040, 'title': '方向 C · 杂志（存档）', 'page': 'page-3'},
    ],
    'annotations': [
        {'id': 'system-note', 'x': 0, 'y': -260, 'w': 640, 'page': 'page-1',
         'text': '设计规则：斯堪的纳维亚风格。纯黑透明度做层级，不用带色相的灰；空间优先于边框；左对齐；一屏三到四种字体样式；控件高 40，圆角 8。\n两处有意的例外：期头与登录标语用霞鹜文楷（产品身份），元数据用 Maple Mono（数据与正文分开）。\n图标为 Lucide 描边，实现时经 morphicons 做形变过渡。组件结构对应 shadcn/ui。\n条目全是虚构样例。'},
        {'id': 'components-note', 'x': 1560, 'y': 0, 'w': 520, 'page': 'page-2',
         'text': '本页是给实现用的规范：颜色阶梯、字体角色、按钮与输入的状态、标签页与筛选、状态语义、列表行尺寸、图标集、间距。写实现计划时按此落令牌。'},
        {'id': 'archive-note', 'x': 0, 'y': -200, 'w': 520, 'page': 'page-3',
         'text': '第一轮的三个方向草稿，仅存档参考，已被斯堪的纳维亚方案取代。'},
    ],
    'launch': {'view': 'canvas', 'page': 'page-1'},
}
with open(os.path.join(out, 'canvas.json'), 'w', encoding='utf-8') as f:
    json.dump(canvas, f, ensure_ascii=False, indent=2)
print('built', len(pages), 'pages +3 archived ->', out)
