# 命名决策 / Naming

最后更新：2026-10-23

## 决定

- 中文名：**《回响》**（继续使用，未做正式商标检索）。
- 英文工作名：**Take Stack**。
- v0.1.14 起已切换：`project.godot` 的 `config/name`、窗口名、导出包名、README/STORE 均已使用 Take Stack。
- 旧 `Reverb` 用户目录会在首次启动时自动迁移到 `Take Stack`：`reverb_save.json`、`settings.json`、`runs.jsonl`，已存在的新文件不会被覆盖。
- 代码里的环境变量前缀 `REVERB_*`（`REVERB_SAVE`、`REVERB_RUN_LOG`、`REVERB_SETTINGS`、`REVERB_LANG`）暂时保留，避免工具与测试失效；它们不是用户可见名称。
- GitHub 仓库 slug 仍是 `reverb`，避免旧链接失效；商店和宣传统一用 Take Stack。

## 为什么是 Take Stack

- 直接对应核心机制：录像是一张 take，槽位有限，叠录是把两张 take 合成一叠。
- 检索未发现同名 Steam 游戏（2026-10-23，非正式商标检索）。
- 不像 Ghost Take / Dead Take 那样把游戏误读成恐怖类型。
- 两个常见词，易读、易搜；中文《回响》保留，不强行直译。

## 免费检索记录（2026-10-23）

- 普通网页检索：没有发现 `Take Stack` 的游戏或商标明确占用。
- Justia：关键词返回 500 条宽泛的 “stack” 结果，首屏没有精确同名；这不是“无冲突”的结论。
- USPTO 新版检索页：当前网络下被 WAF/加载卡住，尚未完成官方查询。
- 结论：可以继续作为工作名，但不能视为商标可用；正式 USPTO/CNIPA/EUIPO 检索仍然必须做。

## 已排除

| 名字 | 原因 |
|---|---|
| Reverb | Steam 2514890（多人潜行 FPS）、Steam 5085070（四轨音游，2026-09-03）；另有 HP Reverb、Reverb Communications |
| Last Take | 已有同名独立游戏概念/原型，另有体育节目与电影用法 |
| Dead Take | Steam 3352690，已发售恐怖游戏 |
| Overdub | 与 `Paratopic: Overdub`（Steam 3781550）冲突 |
| Ghost Take | 未发现同名 Steam 游戏，但 ghost 容易被理解成恐怖；作为备选 |
| Take Twenty | 未发现同名 Steam 游戏，但把名字绑死在 20 波；作为备选 |

## 仍需完成

1. 做 USPTO / CNIPA / EUIPO 至少一个市场的正式商标检索；确认 Nice class 9（游戏软件）与 41（娱乐）。
2. 查 `takestack.com`、Steam 商店名、主要社交账号；未确认前不要开公开账号。
3. 如果以后改 GitHub 仓库 slug，先确认 release 链接、README、STORE 里的旧链接都有重定向或全部替换。
4. 商店页、capsule、预告片、截图统一用新名；中文《回响》与英文 Take Stack 同时出现时，固定“回响 / Take Stack”的顺序。
5. Steam 页面和 build 的最终名称要在商标结果之后锁定，不能把工作名当法律意见。
