# 回响 / Take Stack 0.18 · 纸上见真章

武器自动开火，纸做的身体现在更清楚地承担后果。

- **六类纸张动作，覆盖35把武器。** 钉穿留下纸孔与夹钉，压印留下墨边，裁切错开纸片，墨迹落地晕开，回卷有真实返程钩尾，传导留下短缝线。目标沿真实来向压折，走路仍由实际位移驱动。
- **身体与工位真的接触。** 修补落在受疗身体的胸袖并短暂挺直；回响按装备能力折叠、抽丝或压成废件；纸手与服务握柄连成压下、回弹的过程。
- **四处反馈修正。** 同ID武器按实际装备槽独立后坐；完全挡住的攻击使用防守反馈，实际掉血才表现受伤；支援出生、攻击、维修、受伤、毁坏与过期接通画面和声音；修好且停机的机器仍显示补丁。
- **保持回收局的纸与墨。** 沿用现有纸偶和办公废件美术，减少特效模式保留必要接触和结果。支援与回响使用真实身份、生命和寿命，不产生额外身体或奖励。

This release keeps the existing paper cast and gives attacks a visible departure,
contact and result. All 35 weapon profiles use six paper actions. Repairs,
retirement and machine grips have physical feedback; equal weapons recoil in
their actual slots, and full shield blocks are distinct from HP injury.

## 下载 / Downloads

下载对应平台ZIP，解压后运行：

- [macOS](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-macos.zip)
- [Windows](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-windows.zip)
- [Linux](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-linux.zip)

macOS包含有效ad-hoc完整性签名，尚未经过Apple公证；首次打开请按包内
`MAC_START_HERE.txt` 操作。Windows包未签名。Linux可执行权限保留在ZIP中。

## 存档 / Saves

**0.18可继续0.17中途存档，无需重开。** Snapshot v4与既有永久档案格式未变；
公开包继续使用 `TakeStack Preview` 目录。更早的中途存档格式需要新开对局，
永久角色解锁、设置和回响档案保留。

0.18 retains Snapshot v4 and the published 0.17 data directory. Existing 0.17 runs
and permanent progress remain usable. Earlier suspended-run formats need a new run.

## 构建与验证 / Build and evidence

本版从tag指向的完整提交在远端流水线重新构建。三平台测试、导出启动、资源审计、
Mac签名与存档隔离，以及普通／中文960／减少特效三套原生动作样板是发版门禁。
最终来源、版本、Godot版本和各文件SHA256以附带 `BUILD_INFO.txt`、`AUDIT.json`、
`VERIFICATION.json`、`PERFORMANCE.json` 与 `SHA256SUMS.txt` 为准。

原生样板是脚本夹具：三套各12场景、56张原尺寸PNG，附60fps静音原速录像、
完整状态／双RNG不变和严格存档往返证据；并非真人通关或平衡结论。
压力对照固定96敌人、8回响、12支援物和既有弹量上限，使用同一探针SHA与同一runner；
性能结果是软件渲染诊断，不能换算为所有设备的FPS承诺。极限叠堆仍不能逐个分辨每具身体。

Human feel, subjective audio, physical controllers and target-device performance
remain playtest work. The attached source/evidence receipts describe what was
actually built and measured, without relabelling automated fixtures as human play.
