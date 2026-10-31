# Take Stack 0.18.2 · Read the terms before you sign.

Before you confirm, the shop says what you keep, what you spend, and what you get. Those words use the same per-shot numbers as the rules.

- **One sentence per offer.** A new gun states damage per shot, the gap between shots, and whether it fills an empty slot or replaces one you already carry. An upgrade shows the current shot and the next shot. Interest states what you earned, what you were paid, and the next threshold.
- **The first fight requires a walk.** Wave 1 does not end on the timer until you have moved. One line says so. The ability is not advertised until the second fight.
- **The floor prompt is the action.** Rescue, repair, and the recycler use one `[E]` sentence. Negotiation is the choice sheet; there is no second prompt on the floor. A rescue or repair result stays up long enough to read.
- **Comparison stays in one place.** Lock sits with the decision, not on the card. Echo merge is one screen: host, donor, trait. The ending report is opaque paper over the press.
- **Keep your shift.** Snapshot v4 and the published data directory are unchanged. Real 0.17, 0.18, and 0.18.1 wave/shop saves continue.

确认前，商店写出留下什么、花掉什么、得到什么，数字和规则是同一套。第 1 场要先走路才结束。救援、维修、回收是同一句 `[E]`。谈判不再在地上多放一个提示。存档格式不变。

## Downloads / 下载

- [macOS](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-macos.zip)
- [Windows](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-windows.zip)
- [Linux](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-linux.zip)

Extract the ZIP and run the game. macOS has an audited ad-hoc integrity signature and is not Apple-notarized; follow the included `MAC_START_HERE.txt` on first launch. Windows builds are unsigned. Linux executable permissions are preserved in the ZIP.

下载入口保持不变。macOS 首次启动请按包内说明操作。

## Saves / 存档

**0.18.2 continues 0.17, 0.18, and 0.18.1 suspended runs.** Permanent role unlocks, settings and saved Echo archives remain. Earlier suspended-run formats require a new run. The public game continues using its existing `TakeStack Preview` data directory.

0.17、0.18、0.18.1 的中途存档可直接继续，无需重开；永久解锁、设置和回响档案保留。

## Build and evidence / 构建与验证

The tag is rebuilt in GitHub Actions. Release gates include Linux, macOS and Windows tests/startup, immutable resource and macOS-signature audits, exact source/package hashes, and actual cross-version wave/shop save restores.

The attached native evidence contains English 1280×720, Chinese 960×540 and Reduced Effects variants: twenty scenes and 95 original-size PNGs per variant, plus normal-speed 60fps silent movies. Every scene proves rendering leaves the full simulation snapshot and both RNG streams unchanged. These are disclosed scripted fixtures, with staged positions and durable targets.

Pressure evidence compares this version with public 0.18 using the same probe and runner, retaining 96 enemies, eight Echoes and twelve supports. Software-renderer measurements describe that diagnostic, not target-device FPS.

See `BUILD_INFO.txt`, `AUDIT.json`, `VERIFICATION.json`, `PERFORMANCE.json` and `SHA256SUMS.txt` for the exact source and results. Published downloads are downloaded again and checked against the audited bytes before Latest changes.

Human play feel, subjective audio and physical-controller testing remain unverified.
