# Kimi Code 5 小时额度用满、任务跑到一半怎么办

```{contents}
```

用 Kimi Code 跑长任务（批量重构、全仓测试修复、文档生成）时，最让人心里一凉的一幕是：任务跑到一半，终端蹦出：

```text
error, status code: 429, message: You've reached your 5-hour usage limit.
Your quota will reset when the current 5-hour window ends.
```

先别慌，记住两个事实，这件事就没那么可怕：

1. **5 小时额度是滚动速率窗口，不是"今天的额度用完了"**。窗口结束额度自动重置，具体时间可以在 Kimi Code Console 查看。
2. **会话完整保存在本地，任务上下文不会丢**。Kimi Code CLI 把每次对话持久化在 `~/.kimi-code/sessions/` 下（按工作目录分组），关掉终端也能原地接上。

真正要解决的只有一个问题：**等额度恢复后，怎么让任务"接着跑"而不是"从头跑"**。下面按成本从低到高给三档方案。

## 方案一：等窗口重置，`kimi --continue` 接着跑（零成本）

这是默认推荐的做法，适合任务不急、不想额外花钱的场景。

额度恢复后，在原工作目录执行：

```bash
kimi --continue    # 简写 kimi -c，恢复当前目录最近的会话
```

如果想恢复的不是最近一次会话，可以交互式挑选或按 ID 指定：

```bash
kimi --session           # 浏览历史会话列表，选一个恢复
kimi --session abc123    # 直接恢复指定 ID 的会话
```

注意 `--continue` 和 `--session` 互斥，不能同时传。已经在 TUI 里的话，不用退出，直接用 `/sessions`（别名 `/resume`）切换会话。

恢复之后，不要重新描述一遍任务，第一句这样写就够了：

```text
继续刚才的任务。先检查一下已完成的部分（文件改动、测试状态），再从中断处接着做。
```

模型能看到完整的消息历史和工具调用记录，让它先自查现场再继续，可以避免重复劳动，也能发现"最后一个工具调用做了一半"的残留状态。

**如果中断前用了 `/goal` 模式**：恢复带有活跃 goal 的会话时，goal 会自动进入 paused 状态（模型/运行时错误也会导致 paused），需要手动 `/goal resume` 才会继续自主推进。这一点很容易忘，恢复后值得先 `/goal status` 看一眼。

## 方案二：提前开 Extra Usage，额度耗尽也不中断（花小钱）

如果任务不能停（比如发版前夜的修复），与其事后补救，不如提前把"保险"买好。

Kimi 会员可以开启 **Extra Usage（额外用量）**：订阅额度用完后自动从充值余额扣费，**无缝切换，任务不会停、不报错**。CLI、网页版 Kimi 共享同一个余额。

- **开启方式**：Kimi 订阅页底部的 Extra Usage 模块充值并打开开关；当 5 小时额度用量超过 80% 时，Kimi Code Console 的进度卡片也会出现购买入口。
- **花费控制**：设置里可以开"月度消费上限"，防止长任务把余额跑穿。定价接近开放平台 API 价，官方给的量级参考是：简单请求约 ¥0.03，复杂多步任务约 ¥1.6。重度使用者升级套餐通常更划算。
- **余额规则**：不过期、可叠加；先扣订阅额度，余额最后兜底。CLI 里输入 `/usage` 可以直接查用量。
- **一个坑要知道**：余额快用完时，官方只保证"最后一次模型调用"会跑完，**不保证整个任务跑完**。所以 Extra Usage 也不能替代方案三的断点续跑习惯。

## 方案三：让任务本身"可断点续跑"（治本）

前两档解决"这一次怎么办"，这一档解决"以后都不慌"。核心思路是：**别把宝押在一个超长会话上，让进度落在磁盘上，而不是只存在于上下文里。**

- **大任务拆小**：把"重构整个仓库"拆成"重构 A 模块 → 跑测试 → 提交 → 重构 B 模块"。每个子任务一个会话，即使被 429 打断，损失也只有一个子任务的上下文。
- **用 `/goal` 描述终点而不是步骤**：`/goal 修复所有 checkout 测试并跑通测试套件` 这种带验收标准的写法，中断恢复后 `/goal resume` 就能继续自主推进，不需要你重新指挥。还可以 `/goal next` 排队后续目标。
- **及时提交，让 git 当进度本**：每完成一个可验证的阶段就 commit。恢复会话后模型 `git status` + `git log` 一看就知道做到哪了，这比任何提示词都可靠。
- **长会话主动 `/compact`**：上下文接近窗口上限时会自动压缩，但长任务里主动 `/compact 保留数据库迁移相关的讨论` 可以控制压缩保留什么，减少"恢复后失忆"的概率。
- **重要节点 `/export-md` 存档**：把会话导出成 Markdown，既方便复盘，也能在极端情况下（会话损坏、换机器）把背景贴进新会话。

## 三档方案对比与建议

| 方案 | 成本 | 任务是否中断 | 适用场景 |
|---|---|---|---|
| 一：等重置 + `--continue` | 免费 | 中断，等窗口结束 | 默认选择，任务不急 |
| 二：Extra Usage | 按量付费，可设月度上限 | 不中断 | 任务紧急、不能等 |
| 三：断点续跑习惯 | 要花心思拆任务 | 中断也损失很小 | 所有长任务，治本 |

**我的建议：方案三是日常习惯，方案一是默认动作，方案二是可选保险。** 即：平时就用"拆任务 + `/goal` + 勤提交"的方式工作，真撞上限就 `--continue` 接上；只有任务紧急时才需要提前开 Extra Usage。

## 几个容易混淆的点

- **5 小时窗口 ≠ 周额度 ≠ 月度总额度**。5 小时是滚动速率窗口，人人都有；老套餐（Andante 等）另有 7 天刷新的周额度，新套餐（Plus 起）已取消周限制；所有会员还共享一个月度总额度（PPT、Agent、Kimi Code 等权益一起算），月度耗尽会冻结到下个账期。报错信息里写的是什么窗口，就按什么窗口等。
- **429 额度错误重试无意义**。官方错误文档明确说：等窗口重置、买 Extra Usage 或升级套餐，重试解决不了。但 `We're receiving too many requests`、`The engine is currently overloaded` 这类 429 是瞬时限流，稍等重试即可，跟你的额度无关。
- **不要手改 `~/.kimi-code/sessions/` 里的文件**，可能导致会话无法恢复。要备份就用 `kimi export <sessionId>` 打 ZIP 包。
- **恢复会话可以顺便切权限模式**：`kimi --continue --auto` 恢复最近会话并切到自动模式，适合恢复后让它无人值守继续跑（仅限可信目录）。

## 参考

- [Membership Benefits — Kimi Code 官方文档](https://www.kimi.com/code/docs/en/kimi-code/membership.html)：5 小时滚动窗口、Extra Usage 规则
- [Sessions and context](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/sessions.html)：会话存储、恢复、`/compact`、`/fork`、导出
- [kimi command reference](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command.html)：`--continue` / `--session` 参数与互斥规则
- [Goals](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/goals.html)：goal 模式生命周期、paused / resume 行为
- [Error Reference](https://www.kimi.com/code/docs/en/kimi-code/error-reference.html)：429 各类额度错误与瞬时限流的区别

## 版本记录

| 版本 | 日期 | 模型 | 说明 |
|---|---|---|---|
| v1 | 2026-11-02 | kimi-for-coding (Kimi Code CLI) | 初稿：三档方案（等重置续跑 / Extra Usage / 断点续跑习惯）、对比表、易混淆点 |

本次消耗：见文末统计（按当前会话 wire.jsonl 的 usage 字段汇总）。
