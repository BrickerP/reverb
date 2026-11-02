# Take Stack 0.18.8 · Your route comes back.

The demo's second wave replays the path you just walked. A purchase is a click on the offer. When a copy stands in the cross, that copy tears and you do not.

- **Demo.** Wave 1 is only you. Wave 2 puts that recording on the field and lets it fire. The demo shop closes after that wave. Daily runs do not keep the demo flag.
- **Shop.** Click the offer card to buy. An empty slot click spends nothing; dropping a card on a slot still installs it. Weapons show I / II / III / IV. An upgrade reads as the next grade and its price. Binding two copies names the action: inherit, repair, or reinforce.
- **The cross.** A copy inside the cross is spent as a block, not as natural wear. The tear stops on the copy. Your body keeps a closed mark and its hit points.
- **Keep your shift.** Snapshot v4 is unchanged. A walked first wave is stored. An ungraded shot and an unwalked wave omit those fields, so 0.17 through 0.18.7 saves keep their original bytes.

试玩第二场回放你刚才走过的路。购买只点商品卡。副本站在十字里时，撕开的是副本，不是你。

- **试玩。** 第一场只有你。第二场把这段记录放回场上并让它开火。打完这一场，试玩才停。每日挑战不会带上试玩标记。
- **商店。** 点商品卡才扣钱。点空槽不扣钱；把卡拖进槽里仍然装配。武器显示 I／II／III／IV。升级写成下一级和价格。两份回响装订时，按钮写明继承、修复或强化。
- **十字。** 副本挡住这一下，不算自己耗尽。撕裂停在副本身上。你的身体留下挡住的痕迹，生命不动。
- **存档。** 仍是 Snapshot v4。第一波已经走过的距离会保存。没走过、弹丸没有等级时不写这两个字段，0.17 到 0.18.7 的原文还能原样续读。

## Downloads / 下载

- [macOS](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-macos.zip)
- [Windows](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-windows.zip)
- [Linux](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-linux.zip)

Extract the ZIP and run the game. macOS has an audited ad-hoc integrity signature and is not Apple-notarized; follow the included `MAC_START_HERE.txt` on first launch. Windows builds are unsigned. Linux executable permissions are preserved in the ZIP.

下载入口保持不变。macOS 首次启动请按包内说明操作。

## Saves / 存档

**0.18.8 continues 0.17, 0.18, 0.18.1, 0.18.2, 0.18.3, 0.18.4, 0.18.5, 0.18.6, and 0.18.7 suspended runs.** Permanent role unlocks, settings and saved Echo archives remain. Earlier suspended-run formats require a new run. The public game continues using its existing `TakeStack Preview` data directory.

0.17、0.18、0.18.1、0.18.2、0.18.3、0.18.4、0.18.5、0.18.6、0.18.7 的中途存档可直接继续，无需重开；永久解锁、设置和回响档案保留。

## Build and evidence / 构建与验证

The tag is rebuilt in GitHub Actions. Release gates include Linux, macOS and Windows tests/startup, immutable resource and macOS-signature audits, exact source/package hashes, and actual cross-version wave/shop save restores.

The attached native evidence contains English 1280×720, Chinese 960×540 and Reduced Effects variants: twenty scenes and 95 original-size PNGs per variant, plus normal-speed 60fps silent movies. Every scene proves rendering leaves the full simulation snapshot and both RNG streams unchanged. These are disclosed scripted fixtures, with staged positions and durable targets.

Pressure evidence compares this version with public 0.18 using the same probe and runner, retaining 96 enemies, eight Echoes and twelve supports. Software-renderer measurements describe that diagnostic, not target-device FPS.

See `BUILD_INFO.txt`, `AUDIT.json`, `VERIFICATION.json`, `PERFORMANCE.json` and `SHA256SUMS.txt` for the exact source and results. Published downloads are downloaded again and checked against the audited bytes before Latest changes.

Human play feel, subjective audio and physical-controller testing remain unverified.
