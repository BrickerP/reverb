# 回响 / Take Stack

![Test](https://github.com/BrickerP/reverb/actions/workflows/test.yml/badge.svg)

在废件回收局，昨天的你会被复印、装订，再送回战场。这个自动射击 roguelite 把每波的走位和装备录成一张「回响」：让过去的自己替你打，花材料修补它，或者亲手报废它，换取一次由武器决定的技能。

当前源码是 **0.14 开发预览**：20 波主线、可跟随镜头探索的回收工场、6 个角色、24 把武器、叠录与修补、完整中途保存、可选故事线索，以及原创《Paperwork Waltz》配乐。纸偶、办公废件和粗墨纸卡共同构成 **Carbon Copy Purgatory / 废件回收局**。

![wave](docs/wave.png)
![shop](docs/shop.png)
![echo selection](docs/echo_selection.png)
![story archive](docs/story.png)
![boss](docs/boss.png)
![character select](docs/select.png)

## 怎么玩

- 只控制移动，武器自动攻击。2400×1200 的工场里有五台能挡住身体和弹道的机器；镜头跟随玩家，HUD 固定。绕掩体、躲开明确预警的冲刺和重击，再利用敌人的恢复空档。
- 主线有 20 波，普通波 20–60 秒，进攻分三段，间有喘息时间。第 20 波的「原件」会封印回响、召唤敌人，并在半血时撕裂成两个真实的碎片。Boss 波持续到全部碎片被击败，之后可继续无尽或 Boss Rush。
- 每波结束，把走位和装备快照录成回响。回响无敌、不挡敌人，下一波沿路线往返播放；套印件的回响则使用当前装备。槽位超出上限时，先在商店整理再开波。
- 回响从 **100 耐久**开始，默认累计播放 **120 秒**耗尽。只有战斗播放会磨损；暂停、选择轮盘和商店都会停住。低耐久不会降低伤害，耐久归零会自然报废，不会替你释放完整主动技能。
- **轻按 Space / RB** 消耗当前选中的回响，释放钉固、重压、切割、墨迹、回收或电弧技能。技能取决于它的主导武器；HUD 会显示预测。**按住**打开暂停的选择轮盘，松开只切换回响。没有每波一次的限制，每次消耗一张回响，另有短暂防误触间隔。
- 商店有 4 个报价，可刷新、保留 1 个报价、升级、进化、卖出或替换武器。满 6 格仍会出现武器报价，购买时选择替换槽位。装备与回响整理共用撤销历史。
- 修补一次最多恢复 **40 耐久**，价格随实际恢复量变化。叠录把两条路线和最多 8 件武器合成一张回响，保留两者较低的耐久。长播放道具增加 40 秒播放时长。
- 武器共六家族，每家族有 3 把商店武器和 1 把进化形态。钉住敌人后用冲压武器追击、给敌人染墨后触发奥术传导，都是实际命中产生的组合；构筑面板会解释条件。
- 第 3、6、9…个非 Boss 波中段会出现可选补给，8 秒后过期；必须亲自靠近收取。波间还可选择付押金的异常合约。
- 故事通过短收据与档案展开：是谁在签发你的报废单？修补、主动报废、自然耗尽与通关都会留下线索，阅读不影响战斗。

| 角色 | 起始特点 | 解锁 |
|---|---|---|
| 折痕 / Creased | 3 槽、40% 回响威力，手枪开局 | 初始 |
| 拒收件 / Reject | 无回响，咒矢与强化的本体属性 | 最佳波数 10 |
| 套印件 / Misprint | 2 槽、40% 威力，回响实时复制当前装备 | 通关 1 次 |
| 装订员 / Binder | 4 槽、22% 威力，每张活跃回响强化全队 | 最佳波数 15 |
| 修补员 / Mender | 3 槽、40% 威力，拾取材料修补选中回响，商店修补优惠 25% | 最佳波数 5 |
| 超载员 / Overloader | 2 槽、50% 威力，磨损 ×1.35，主动报废威力 ×1.5 | 最佳波数 12 |

## 操作与保存

| 操作 | 键位 |
|---|---|
| 移动 | WASD / 方向键 / 左摇杆 / 十字键 |
| 开火 | 自动 |
| 报废选中回响 | 轻按 Space / RB |
| 选择回响 | 按住 Space / RB，轮盘中选择，松开确认 |
| 暂停 / 返回 | P / Esc / Start |
| 设置 | O |
| 对局记录（选角 / 结算） | H |
| 保存并返回选角（暂停时） | Q，或暂停菜单按钮 |
| 静音 | M |
| 调试信息 | F3 / 手柄 View |
| 结算：重开 / 重试种子 / 换角色 | R / S / C |
| 菜单与商店 | 鼠标；键盘焦点与确认；手柄十字键、A 确认、B 返回 |

暂停菜单的 **保存并返回** 与标题页 **继续** 可恢复战斗或商店，包括敌人预警、弹道、回响播放与耐久、录制进度、报价保留与撤销、待选恩惠。切换语言保留当前对局，关闭窗口也会先保存。保存失败会显示错误并保留当前对局。开始新局会在存在保存时要求确认替换。

0.14 起预览构建使用固定的 `TakeStack Preview` 数据目录，后续兼容更新共享同一份进度；与旧正式版、0.13 临时预览目录分开。

设置包含独立的总音量、音乐与音效音量、静音、震动、减弱特效、全屏和语言。英文与中文使用内置字体。每日挑战、种子重试、苦行等级、本地历史、无尽与 Boss Rush 均可从游戏界面进入。

## 下载与运行

从 [GitHub Releases](https://github.com/BrickerP/reverb/releases) 下载；每个发布页注明自己的版本与验证范围，源码预览不代表已发布的新包。

- **macOS**：解压后将 `Take Stack.app` 移到 Applications。预览包使用 Godot 内置的 **ad-hoc 本地签名**，未使用 Apple Developer ID，也未经过公证。首次启动若被系统拦截，先尝试打开，再到“系统设置 → 隐私与安全性”，针对 **Take Stack** 选择“仍要打开”。包的签名完整性检查必须通过。
- **Windows**：解压 `TakeStack-windows.zip`，运行 `TakeStack.exe`。预览程序未签名，可能出现 SmartScreen 提示。
- **Linux**：解压 `TakeStack-linux.zip`，给 `TakeStack.x86_64` 执行权限后运行。
- 发布包提供 `SHA256SUMS.txt`；macOS 可用 `shasum -a 256 -c SHA256SUMS.txt` 校验。

从源码运行需要 **Godot 4.7.2**，游戏运行不需要 Python：

```bash
git clone https://github.com/BrickerP/reverb.git
cd reverb
make run
make run-zh
```

也可用 Godot 打开 `project.godot` 后按 F5。语言默认跟随系统，可用 `REVERB_LANG=en` 或 `REVERB_LANG=zh` 覆盖。

## 开发与验证

```bash
make test       # 导入并运行无头测试
make smoke      # 主场景流程烟测
make perf       # 模拟压力测试
make frames     # 真实窗口帧耗时，需要显示器
make export     # 三平台导出，需要 Godot export templates
python3 -m pip install -r tools/requirements-audio.txt
python3 tools/build_original_score.py --audition-dir /absolute/output/audio
python3 -m unittest discover -s tests -p 'test_*.py'
```

配乐生成的开发依赖固定为 NumPy 2.0.2；CI 使用 Python 3.12。35 个纸张 / 办公机器音效保留独立的生成配方。原生流程探针为 `tools/core_gameplay_probe.gd`；语言重载、真实音频生命周期、渲染压力与帧时间有各自探针。导出审计从固定提交构建，在新目录解压实际 ZIP，检查资源、来源材料、启动与 macOS 全架构严格签名。

这些检查覆盖确定性、保存恢复、渲染与资源完整性；真人平衡、主观听感、实体手柄、Steam Deck、低端硬件及 Windows / Linux 图形界面仍需实机验证。帧时间取决于机器与场景，不承诺所有设备稳定 60 FPS。

完成的对局只写入本机 `user://runs.jsonl`，不上传。结算页可打开记录文件夹；文件位于 Godot 的 `app_userdata/Take Stack` 下。自愿提供反馈与开发者报告工具见 [试玩反馈](docs/playtest-feedback.md)。

设计与接口：[DESIGN.md](DESIGN.md)、[INTERFACES.md](INTERFACES.md)；美术与战斗表现：[art-direction.md](docs/art-direction.md)、[battle-direction.md](docs/battle-direction.md)；商店素材：[STORE.md](STORE.md)。

## 许可

代码与文档采用 [MIT](LICENSE)。原创插画与配乐的生产来源随仓库保留；字体采用 SIL OFL 1.1，纸张 / 机器录音包含 Kenney CC0 素材。Godot 与开发技能包的许可及具体来源见 [THIRD_PARTY.md](THIRD_PARTY.md)。
