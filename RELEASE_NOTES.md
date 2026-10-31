# Take Stack 0.18.1 · Hands required. Staff optional.

The paper crew now follows through on its work: Echoes reach for the machines they recorded, role abilities move the paper body, and rescued workers visibly leave their restraints.

- **Readable fire in busy fights.** Six compact material accents distinguish pins, stamps, cuts, ink, returns and arcs. Dense and Reduced Effects scenes keep a bounded, fairly sampled set of accents while every real projectile head remains visible.
- **Echoes operate the machinery.** Recorded work drives the actual copy's hand and the real lever. Missing, muted, sealed or out-of-range workers cannot animate a successful operation.
- **Six role actions.** Rewind, dash, swap, relay, repair and overload have finite body gestures tied to their committed result. Movement settles without restarting the old automatic-fire body tremor.
- **Rescue has a departure.** Shackles open at the worker's original position, a paper silhouette leaves for safety, and the real safe worker settles into view. This adds no extra damageable actor or reward.
- **Keep your shift.** Snapshot v4 and the published data directory remain unchanged. Real 0.17 and 0.18 wave/shop saves are resumed by the release gates.

回响会伸手压下旧路线上的拉杆；六名角色的技能有了身体动作；被救下的工友会先挣脱、再离开。高弹量和减少特效模式保留有上限的纸张材质线索，避免所有攻击只剩细线与小点。

## Downloads / 下载

- [macOS](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-macos.zip)
- [Windows](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-windows.zip)
- [Linux](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-linux.zip)

Extract the ZIP and run the game. macOS has an audited ad-hoc integrity signature and is not Apple-notarized; follow the included `MAC_START_HERE.txt` on first launch. Windows builds are unsigned. Linux executable permissions are preserved in the ZIP.

下载入口保持不变。macOS 首次启动请按包内说明操作。

## Saves / 存档

**0.18.1 continues 0.17 and 0.18 suspended runs.** Permanent role unlocks, settings and saved Echo archives remain. Earlier suspended-run formats require a new run. The public game continues using its existing `TakeStack Preview` data directory.

0.17、0.18 的中途存档可直接继续，无需重开；永久解锁、设置和回响档案保留。

## Build and evidence / 构建与验证

The tag is rebuilt in GitHub Actions. Release gates include Linux, macOS and Windows tests/startup, immutable resource and macOS-signature audits, exact source/package hashes, and actual cross-version wave/shop save restores.

The attached native evidence contains English 1280×720, Chinese 960×540 and Reduced Effects variants: twenty scenes and 95 original-size PNGs per variant, plus normal-speed 60fps silent movies. Every scene proves rendering leaves the full simulation snapshot and both RNG streams unchanged. These are disclosed scripted fixtures, with staged positions and durable targets.

Pressure evidence compares this version with public 0.18 using the same probe and runner, retaining 96 enemies, eight Echoes and twelve supports. Software-renderer measurements describe that diagnostic, not target-device FPS.

See `BUILD_INFO.txt`, `AUDIT.json`, `VERIFICATION.json`, `PERFORMANCE.json` and `SHA256SUMS.txt` for the exact source and results. Published downloads are downloaded again and checked against the audited bytes before Latest changes.

Human play feel, subjective audio and physical-controller testing remain unverified.
