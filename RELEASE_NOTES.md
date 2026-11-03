# Take Stack 0.18.9 · Please inspect before signing.

The shop puts the goods up front. The fine print waits until you ask for it.

- **One offer, one place to look.** Larger artwork sits beside the name, grade and a single price/action. Buying still works by clicking the offer or dragging it into a slot.
- **A visual loadout.** Weapon tiles show their actual artwork. Eight Echoes fit as paper dolls with carried weapons, route traces and wear bars. A worn copy crumples; a bound copy carries a staple mark.
- **Inspect in layers.** Hover or focus for short facts. Hover a rule term for its explanation. Click, right-click, F1 or controller Y to pin an inspection; open Details for management. Back closes the deepest layer first and returns focus to its source.
- **Fewer scattered controls.** Upgrade and Loadout stay in the equipment header. Combining, evolution and selling belong to the selected weapon. Global stats and passives live in Loadout. Wide windows show equipment and Echoes together; compact windows keep their pages.
- **Keep your place.** Upgrades and Undo preserve the stock's scroll position. Rerolls and new shops return to the start. Inspections stay clear of the footer and close during dragging or a transaction.

商店先把货摆清楚。小字等你想看时再拿出来。

- **一张商品，一个阅读方向。** 左边放大图片，右边集中名称、等级和唯一的价格／操作。仍可点击购买或拖入装备槽。
- **装备与回响先看图。** 武器用真实外形；八份回响以纸偶展示携带武器、路线和磨损。快报废的纸偶皱缩，装订过的留下钉痕。
- **按需展开。** 悬停或聚焦看要点；移到规则词上再看解释。点击、右键、F1 或手柄 Y 固定查看，进入详情管理。返回时逐层收起，焦点回到原处。
- **操作归位。** 装备区顶部保留升级与构筑；合成、进化、出售跟随所选武器。全局属性和被动道具收进构筑。宽窗口同时展示装备与回响，小窗口保留分页。
- **别把人送回页首。** 升级与撤销保留商品列表位置；刷新或进入新商店才回到开头。悬浮层避开底部按钮，拖拽和交易时收起。

## Downloads / 下载

- [macOS](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-macos.zip)
- [Windows](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-windows.zip)
- [Linux](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-linux.zip)

Extract the ZIP and run the game. macOS has an audited ad-hoc integrity signature and is not Apple-notarized; follow the included `MAC_START_HERE.txt` on first launch. Windows builds are unsigned. Linux executable permissions are preserved in the ZIP.

下载入口保持不变。macOS 首次启动请按包内说明操作。

## Saves / 存档

**0.18.9 continues 0.17, 0.18, and 0.18.1 through 0.18.8 suspended runs.** Snapshot v4 and the existing `TakeStack Preview` data directory are unchanged. Permanent role unlocks, settings and saved Echo archives remain. Earlier suspended-run formats require a new run.

0.17、0.18、0.18.1 至 0.18.8 的中途存档可直接继续；永久解锁、设置和回响档案保留。本次没有修改战斗规则、平衡或存档格式。

## Build and evidence / 构建与验证

The tag is rebuilt in GitHub Actions. Release gates include Linux, macOS and Windows tests/startup, immutable resource and macOS-signature audits, exact source/package hashes, and actual cross-version wave/shop save restores.

The shop probe covers English and Chinese at 1280×720 and 960×540, pointer and simulated-controller navigation, nested inspections, live resizing, purchases, replacement, combining, evolution, and exact Undo. Its captures are disclosed scripted fixtures.

The attached native combat evidence contains English 1280×720, Chinese 960×540 and Reduced Effects variants: twenty scenes and 95 original-size PNGs per variant, plus normal-speed 60fps silent movies. Every scene proves rendering leaves the full simulation snapshot and both RNG streams unchanged. These are scripted fixtures with staged positions and durable targets.

Pressure evidence compares this version with public 0.18 using the same probe and runner, retaining 96 enemies, eight Echoes and twelve supports. Software-renderer measurements describe that diagnostic, not target-device FPS.

See `BUILD_INFO.txt`, `AUDIT.json`, `VERIFICATION.json`, `PERFORMANCE.json` and `SHA256SUMS.txt` for the exact source and results. Uploaded assets are downloaded again and checked against the audited bytes before Latest changes.

Human play feel, first-time comprehension, subjective audio and physical-controller testing remain unverified.
