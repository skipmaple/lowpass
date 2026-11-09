# Lowpass 主题字体构建

此目录保留上游许可、来源与 SHA-256 清单，以及体积较小的拉丁字体原始文件。生成物位于 `app/frontend/fonts/themes/`；UI 与三套内容字体声明分别位于 `app/frontend/styles/fonts.css`、`fonts-{daybreak,duet,unfold}-content.css`。生产构建不依赖 `.impeccable/` 或设计调研缓存。

## 固定输入

| 主题 | 中文原始字体 | 拉丁字体与固定轴 |
| --- | --- | --- |
| A 层叠清晨 | 寒蝉圆黑 Regular / Bold | Bricolage Grotesque：正文 400、18pt；标题／刊头 700–800 连续字重、72pt；宽度 100 |
| B 双声部 | 寒蝉锦书宋 Text Regular / Bold | Newsreader：正文 400、18pt；来源／标题／刊头 600–700 连续字重、48pt |
| C 展开阅读 | 未来荧黑 SC Normal Regular / Bold | IBM Plex Sans：正文 400、标题 600，宽度 100；日期 300，宽度 75 |
| 共用数据字体 | — | IBM Plex Mono 400 |

- `sources.json`：中文上游固定 commit / release 地址、OTF 校验值、C 的 ZIP 校验值与成员名、对应 OFL 校验值。六个中文原始 OTF 合计约 83 MB，构建时下载到外部目录，不重复提交。
- `latin-sources.json`：随仓库保存的三个原始变量 WOFF2 和 Mono 400、Fontsource 包版本、包内路径、文件与许可 SHA-256。
- `latin-instances.json`：七个拉丁角色的全部轴值：数值表示固定轴，双元素数组表示保留的最小／最大范围。A display 的 wght 为 700–800，B display 为 600–700，其余轴保持固定。`bytes` 为原静态实例改名之前的历史调研值，不参与校验或预算；实际输出以构建结果为准。
- `build-inputs.json`：固定 FontTools 4.68.0、Brotli 1.2.1，以及 `lxgw-wenkai-screen-webfont` 1.7.0 字符频率分片 CSS 的 SHA-256。仅借用它的 Unicode 分组，不使用它的字形。
- `*-OFL.txt`：保留上游许可与版权内容。生成后的字体使用 Lowpass 内部名称；不覆盖上游原始字体与许可。

## 获取中文构建源

在仓库根目录执行。示例输出目录可以更换；脚本只写入指定目录，不覆盖仓库内的字体产物。

```sh
python3 - /tmp/lowpass-font-sources <<'PY'
from pathlib import Path
from urllib.request import urlopen
from io import BytesIO
from zipfile import ZipFile
import hashlib, json, sys

out = Path(sys.argv[1])
entries = json.loads(Path('vendor/fonts/themes/sources.json').read_text())
for entry in entries:
    if 'url' not in entry:
        continue
    if not entry.get('members') and not entry.get('file', '').startswith('fonts/'):
        continue
    data = urlopen(entry['url'], timeout=60).read()
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['url']
    if 'members' in entry:
        with ZipFile(BytesIO(data)) as archive:
            for filename, member in entry['members'].items():
                path = out / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.read(member))
    else:
        path = out / entry['file']
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
for entry in entries:
    if entry.get('file', '').startswith('fonts/'):
        assert hashlib.sha256((out / entry['file']).read_bytes()).hexdigest() == entry['sha256'], entry['file']
print(out)
PY
```

`fonts/` 下应有 `a-regular.otf`、`a-bold.otf`、`b-regular.otf`、`b-bold.otf`、`c-regular.otf`、`c-bold.otf`。拉丁与 Mono 已在本目录 `sources/`，不需要调研缓存里的 `latin-instances/`。

## 完整生成

```sh
npm ci
python3 -m venv /tmp/lowpass-font-build
/tmp/lowpass-font-build/bin/pip install 'fonttools[woff]==4.68.0' 'brotli==1.2.1'
/tmp/lowpass-font-build/bin/python script/build_theme_fonts --source-dir /tmp/lowpass-font-sources --jobs 6
```

构建开始前校验工具版本、中文／拉丁原始文件、OFL 文件和分片依据。任意 SHA-256 不符立即停止。`--jobs` 只影响并发数，不改变结果。没有 UI-only 模式：UI 字符集改变时必须完整生成，以避免 UI／内容分片漏字或重叠。

生成规则：

1. 中文 400 / 700 都保留原始字体中 `U+0100` 及以上的完整字符覆盖；`U+0000–00FF` 由各主题拉丁字体承担。
2. UI 常用字单独成为首屏字体；剩余 UI 字与正文分片在相应主题内容 CSS 按需加载。
3. 内容声明按分片编号优先、同一分片 400 后 700 排序，`ui-extra` 放末尾。相同 Unicode 范围紧邻，供 gzip 的 32 KB 字典复用。每套内容 CSS 的 gzip 上限为 56 KiB。
4. 拉丁变量源按已确认轴值实例化，仅 A/B display 保留清单指定的有限 wght 范围，其余轴完全固定；不再发布没有引用的 `a-latin.woff2` / `b-latin.woff2` / `c-latin.woff2` 变量副本。
5. 修改后的 `name` family/full/PostScript/unique/typographic 等身份字段，以及 CFF FontName/FamilyName/FullName/FDArray FontName，统一为 Lowpass；保留原始版权、许可、版本说明。
6. CID CFF 保留真正的 `FDArray[].Private`，移除无用的顶层 `Private` 副本，避免 C 每个分片多出约 80 KB。保留原始 `head` 时间戳，关闭重算时间戳，避免每次构建生成不同二进制。

## 只读验收

```sh
/tmp/lowpass-font-build/bin/python script/build_theme_fonts --source-dir /tmp/lowpass-font-sources --verify
```

验收检查所有 CSS 引用存在、没有孤立 WOFF2、内外字体名与字重一致、保留轴及范围与 manifest/CSS 一致、OS/2 字重等于 fvar 默认值、CFF 内部名称已更新、没有 CID 冗余 Private、每条 CSS 范围都在 cmap 中、分片声明互不重叠、声明并集覆盖上游目标字符集，以及压缩预算。FontTools 可能为同一 glyph 保留额外 cmap 别名；这些别名不会扩大 CSS 声明范围。

2026-11-05 验收基线：1,100 个字体文件，其中中文 1,092 个、拉丁角色 7 个（静态 5 个、有限字重变量 2 个）、Mono 1 个。

| 主题 | 每字重中文字符覆盖 | 内容 CSS gzip |
| --- | ---: | ---: |
| A | 26,958 | 55,034 bytes |
| B | 44,336 | 55,594 bytes |
| C | 32,036 | 53,491 bytes |

本轮没有重新生成全部汉字字形：对既有分片规范化内部名称、恢复原始时间戳，逐文件确认 cmap 与水平 advance metrics 不变；全部分片划分可从固定源重新推导并与现有 CSS 一致。另外以三套 UI 单面重建检查二进制可复现性。

A/B 字重补齐（2026-11-05）：不额外增加字体文件。A display 为 35,344 bytes，较原输出增加 13,164 bytes（12.86 KiB）；B display 为 38,736 bytes，增加 14,544 bytes（14.20 KiB）。两者只保留 `wght` 轴，分别为 700–800（默认 800）和 600–700（默认 600）；`opsz`、`wdth` 仍按清单固定。正文、C、Mono 及所有中文字体的 SHA-256 保持不变。使用校验过的输入调用现有 `build_latin()` 重建后，执行完整 `--verify`；连续两次生成的全部输出 SHA-256 相同。完整生成入口仍是上文的 `script/build_theme_fonts`，没有新增局部 CLI 模式。
