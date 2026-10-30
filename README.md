# 回响 / Take Stack

[English](README.en.md)

**昨天的你，是今天的耗材。**

在废件回收局，你负责走位，武器自己打。每场战斗留下一张回响：它会磨破，可以装订、修补，或者提前报废。结局要自己签字，欠债不会替你选。

![你走，武器自己打](docs/wave.png)

你走，武器自己打。

![回响会磨破](docs/echo_selection.png)

回响会磨破。选一张，装订、修补，或让它再打一次。

![选择会留下签名](docs/story.png)

选择会留下签名。

## 下载

从 [GitHub Releases](https://github.com/BrickerP/reverb/releases) 拿构建。0.16 以对应标签页为准。

- **macOS**：ad-hoc 签名，未公证。若系统提示损坏，这是未公证，不是包坏了。
- **Windows**：未签名，可能触发 SmartScreen。
- **Linux**：给 `TakeStack.x86_64` 执行权限后运行。

想先摸一下这个动词，打开 [纸上的 30 秒](https://brickerp.github.io/reverb/play/)。那不是完整游戏：走，身后跟着三秒前的自己，然后它被揉掉。整页在 [brickerp.github.io/reverb](https://brickerp.github.io/reverb/)。

## 角色

![六名纸偶](docs/select.png)

<details>
<summary>六个人，六种走法</summary>

| 角色 | 主动技 | 解锁 |
|---|---|---|
| 折痕 / Creased | 倒回位置，并倒回回响与武器冷却 | 初始 |
| 拒收件 / Reject | 没有回响。纸冲刺，路径上造成伤害并短暂格挡 | 最佳场次 4 |
| 套印件 / Misprint | 和选中的回响交换位置 | 通关 1 次 |
| 装订员 / Binder | 以选中的回响为锚，放三次接力电弧 | 最佳场次 8 |
| 修补员 / Mender | 放下次数有限的修补站 | 最佳场次 3 |
| 超载员 / Overloader | 报废选中的回响，按它还剩多少耐久打出一击 | 最佳场次 7 |

主动技和报废回响是两套键。条件不够时，主动技不会扣能量。

</details>

## 工作单

![商店里的工作单](docs/shop.png)

<details>
<summary>下一场你要负责什么</summary>

商店固定六件货：两把武器、两件被动、两张不同的工作单。同时只能拿一张。

| 工作单 | 下一场 |
|---|---|
| 打捞 | 零件必须自己捡，波末不代收 |
| 审计 | 终端会变成真的危险区。做完取得放行资格，不替你选结局 |
| 维修 | 去修已经坏着的机器。不买工单也能修 |
| 营救 | 工友会真的受伤。救下的人进名册，不会变成诱饵 |
| 招募 | Boss 倒下后暂停，按它自己的条件谈判 |
| 信用 | 现在拿 30 材料，欠 40。可以以后还 |

故障和遇险的人由下一场的工况决定。买工单是去承担责任，不是把危险买出来。

</details>

## 结局

<details>
<summary>第 12 场之后，自己签字</summary>

- **放行**：有资格就免费，否则付材料，并把现有回响修好。
- **共同离开**：得有真正还活着的工友或同伴。
- **接管回收局**：免费留下。最后一份回响转成职员，不再参战。

债务单独记着。它不会自动变成坏结局。

</details>

## 操作

| 操作 | 键 |
|---|---|
| 移动 | WASD / 方向键 / 左摇杆 |
| 开火 | 自动 |
| 主动技 | Shift / LB |
| 和机器说话 | E / X |
| 报废选中的回响 | 轻点 Space / RB |
| 换一张回响 | 按住 Space / RB，松开确认 |
| 暂停 | P / Esc / Start |

战斗可以保存，回到标题页再继续。0.15 及更早的对局存档不能接着打；解锁、设置和回响档案还在。

数字、槽位和存档格式见 [DESIGN.md](DESIGN.md)。画面和战斗见 [art-direction.md](docs/art-direction.md)、[battle-direction.md](docs/battle-direction.md)。

从源码跑需要 **Godot 4.7.2**：

```bash
git clone https://github.com/BrickerP/reverb.git
cd reverb
make run
```

语言跟系统。要指定的话：`make run-zh`，或 `REVERB_LANG=en`。

## 许可

代码与文档 [MIT](LICENSE)。字体和第三方素材见 [THIRD_PARTY.md](THIRD_PARTY.md)。
