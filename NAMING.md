# 命名决策 / Naming

最后更新：2026-10-23

## 决定

- 中文名：**《回响》**（继续使用，未做正式商标检索）。
- 英文工作名：**Take Stack**。
- 当前代码/构建内部仍使用 `Reverb`：`project.godot` 的 `config/name` 决定 `user://` 路径，现在改会让试玩者的存档、设置和 `runs.jsonl` 落到新目录。等正式更名前再做迁移。
- 因此 v0.1.13 构建的窗口/应用名仍是 `Reverb`；商店与宣传材料使用 `Take Stack`。这不是最终发布状态。

## 为什么是 Take Stack

- 直接对应核心机制：录像是一张 take，槽位有限，叠录是把两张 take 合成一叠。
- 检索未发现同名 Steam 游戏（2026-10-23，非正式商标检索）。
- 不像 Ghost Take / Dead Take 那样把游戏误读成恐怖类型。
- 两个常见词，易读、易搜；中文《回响》可以保留，不强行直译。

## 已排除

| 名字 | 原因 |
|---|---|
| Reverb | Steam 2514890（多人潜行 FPS）、Steam 5085070（四轨音游，2026-09-03）；另有 HP Reverb、Reverb Communications |
| Last Take | 已有同名独立游戏概念/原型，另有体育节目与电影用法 |
| Dead Take | Steam 3352690，已发售恐怖游戏 |
| Overdub | 与 `Paratopic: Overdub`（Steam 3781550）冲突 |
| Ghost Take | 未发现同名 Steam 游戏，但 ghost 容易被理解成恐怖；作为备选 |
| Take Twenty | 未发现同名 Steam 游戏，但把名字绑死在 20 波；作为备选 |

## 正式更名检查清单

1. 做 USPTO / CNIPA / EUIPO 至少一个市场的正式商标检索；确认 Nice class 9（游戏软件）与 41（娱乐）。
2. 查 `takestack.com`、Steam 商店名、主要社交账号；不要在未确认前开公开账号。
3. 改 `project.godot` 的 `config/name`，同时写 `Reverb` → `Take Stack` 的 `user://` 目录迁移，保留 `runs.jsonl`、`reverb_save.json`、`settings.json`。
4. 改 `export_presets.cfg` 的路径/应用名、发布包文件名、README/STORE/DESIGN、截图和 trailer 标题。
5. GitHub 仓库 slug 可以保留 `reverb`（GitHub 会重定向），也可以最后再改；不要同时改仓库和商店，避免链接断两次。
6. 商店页、capsule、预告片统一用新名；中文《回响》与英文 Take Stack 同时出现时，固定“回响 / Take Stack”的顺序。

## 未做

- 正式商标检索、域名/账号占用检索、Steam 商店名预留。
- 代码改名与存档迁移。
- 任何公开商店页或 wishlist 页面。
