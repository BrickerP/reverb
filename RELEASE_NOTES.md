# Take Stack v0.10.0-rc.1

Published 2026-10-25. Tag `v0.10.0-rc.1` points at
`2288b9457366098beec338d5a5dc85a2c74ad141`.

This release is intentionally versioned as a release candidate but was explicitly marked
**Latest** at the maintainer's request.

## Scope

20-wave single-screen arena roguelite vertical slice: record each wave's movement and build,
then let a past self fight as an echo. 20 waves, Paradox boss, shop, four characters, Daily,
Endless and Boss Rush.

Highlights: 4 characters, 12 weapons (4 evolutions), 11 items, 3 item sets, echo overdub /
collapse / refresh / undo, four elite rules, temporal rifts, contracts (including collapse),
endless boons and rerolls, Ascension 0–3, Daily anomalies, streak, history replay, run logs.

## Artifacts

| File | Size | SHA-256 |
|---|---:|---|
| `TakeStack-macos.zip` | 89,302,589 B | `0a30c5783db0167814ac1f06e42d69b343137d87ab764154bf6b64173c23cd79` |
| `TakeStack-windows.zip` | 65,861,077 B | `506f23bfdd5a7cd87f8e932386e438eaea699b2fb6afdf5c97a5ab064ff6cc4c` |
| `TakeStack-linux.zip` | 56,143,055 B | `5103687cf0a67134089b40bad479459dbcf881f4c08cea0cf5dad09ff17e97fd` |

Also attached: `SHA256SUMS.txt`, `AUDIT.json`, `BUILD_INFO.txt`.

## Install

- **macOS**: unzip `TakeStack-macos.zip`, right-click `Take Stack.app` → Open. The build is
  unsigned; if macOS says it is damaged, run
  `xattr -dr com.apple.quarantine "Take Stack.app"`.
- **Windows**: unzip `TakeStack-windows.zip` and run `TakeStack.exe`; keep the `.pck` beside it.
  SmartScreen may require “More info → Run anyway”.
- **Linux**: unzip `TakeStack-linux.zip`, then
  `chmod +x TakeStack.x86_64 && ./TakeStack.x86_64`; keep the `.pck` beside the binary.
- **Checksums**: `shasum -a 256 -c SHA256SUMS.txt` (macOS) or
  `sha256sum -c SHA256SUMS.txt` (Linux).

## Verification

- Godot: **6683 tests passed**
- smoke passed
- Python report tests passed
- exact-head export audit passed for macOS, Windows and Linux
- 18 provenance files, 79 checked resources, 317 inventory items, no forbidden paths
- macOS package launched 30 frames with isolated user data
- Linux executable permission preserved
- `main` CI green
- Remote assets were downloaded and all checksums/zip integrity checks passed before
  publication

## Known limits

- No human playtest data: difficulty, readability, defensive builds, Boss Rush and Daily balance
  remain unverified.
- Formal `Take Stack` trademark clearance is not complete.
- Windows/Linux packages passed native CI export startup smoke; they were not launched on the
  maintainer's macOS host.
