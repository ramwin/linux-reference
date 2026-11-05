# DSH auto-memory 与「每轮手动存文档」是否重复

> 问题：既然每次都让 AI 把对话整理成文档存进 life / linux-reference，
> `dsh-auto-memory` 那层记忆还有存在的意义吗？

## 结论：有，但它的价值只剩一件事——自动注入

两者不是「同一份东西存两遍」，而是**成本模型完全不同**：

| | auto-memory | 仓内文档 |
|---|---|---|
| 什么时候进上下文 | **每个新会话开场自动注入**（索引 ≤4KB/请求） | 只有 AI 主动 Grep/Read 才进来 |
| 谁触发 | DSH 插件，零人工动作 | 用户说「存一下」→ 我写 → 我检索 |
| 最小编码成本 | 一条 `description` | 一篇带章节的文档 |
| 适合的内容 | 一句话事实、偏好、硬约束 | 步骤、命令、数据表、推理过程 |
| 可读性 / 给人看 | 差（无正文，靠索引） | 好（Sphinx 站点） |

**关键差别是「不检索也在场」。** 文档再全，只要我没去翻，就等于不存在；
记忆索引则是每次开场就被塞进 prompt 的。

本次会话就是现成证据（`memory/audit.jsonl` 最后几条）：

- 注入 13 条记忆，**另 7 条因预算被截断**（`truncated` 字段）；
- 注入体积 4053 字节；
- 而 life 仓里 34 篇文档，**一篇都没进上下文**。

如果关掉 auto-memory，那 13 条里的「米饭只吃 1/4」「只在公司慢充」「6:30/7:40 两套起床时间」
这类信息，就只剩「AI 恰好想起来去翻 life 仓」这一条脆弱的路径。

## 但它现在确实在浪费预算

1. **重复记录**。`user-wake-schedule-by-location` 和 life 仓
   [居住与通勤](../../../个人/life/家居/居住与通勤.md) 的作息表是同一份内容；
   `user-car-xiaomi-su7-max` 和 [小米SU7Max充电80还是90](../../../个人/life/出行/小米SU7Max充电80还是90-2026-11-03.md) 重复。
2. **违反自己的规则**。`life-repo-always-save-commit-push` 记的是
   life 仓 `AGENTS.md` 已经写死的「有问必存、存完即推」——按全局约定
   「不重复记录 AGENTS.md 已有的规则」，这条本该删。
3. **description 越写越长**。`user-car-xiaomi-su7-max` 的 description 已经是
   三段小作文；description 就是被注入的那段字，它一胖，就挤掉第 14 条记忆。

## 分工规则（可直接照抄执行）

```
一句话能说清、下次开新会话不用问就该知道、且跨工作区/跨会话复用
  → memory_write（description 控制在 60 字内）

需要步骤/命令/数据表/推理过程/要给人看
  → 仓内文档（life 仓或 linux-reference）

稳定的项目约定（怎么提交、怎么发布、目录结构）
  → AGENTS.md / conventions.md（人写，AI 不改）
```

判断口诀：**「这条信息需要被搜索后阅读吗？」**
需要 → 文档；不需要、只要被「想起来」→ 记忆。

## 具体要做的三件事

1. **删重复**（本次可删）：
   `life-repo-always-save-commit-push`（AGENTS.md 已有）；
   `user-wake-schedule-by-location`（改写成一句「起床看场景，细节见 life 仓
   家居/居住与通勤.md」）。
2. **瘦 description**：`user-car-xiaomi-su7-max` 保留「SU7 Max / 只在公司慢充 /
   8:30 前到才抢得到桩」，其余进文档。
3. **加一道闸**：`memory_write` 之前先问一句「这条 AGENTS.md 里已经有了吗？」
   已有就不写；写了也会在下次注入里挤掉别人。

## 附：为什么不能干脆全塞 AGENTS.md

`dsh-agent-instructions` 的注入预算是 64KB，且**每次请求都带**——
把 30 条记忆写进 AGENTS.md 等于每轮都付一次全量 token。
memory 索引的 4KB 预算是按「索引条目」设计的，正是为了不撑爆这个成本。

## 预算算得比想象的小：maxBytes 不是可用字节

`indexByteBudget(maxBytes)` 的算法是**扣减式**的：

```
净预算 = maxBytes − MEMORY_POLICY_TEXT(~1192B) − 协议壳(~30B) − 96
默认 maxBytes=4096 → 净预算 ≈ 2778 字节
```

那段「When to write a memory…」的写入指导本身就要吃掉 1.2KB，
所以不要拿 4096 当可用量。实测：18 条记忆正文 3725 字节，
**超出 947 字节，约 6 条被截断**（`memory/audit.jsonl` 的 `truncated` 字段会点名）。

调大预算只需在 profile patch 里加一行：

```yaml
- id: auto-memory
  config:
    memoryDir: !!js process.env.HOME + '/github/个人/memory-repo/memory'
    maxBytes: 6144     # 净预算 2778 → 4826
```

改完要重启 `dsh web` 才生效（`cordis.patch.yml` 只在启动时读）。

### 这点 token 到底值不值

实测一次会话：5M token / ¥0.243。索引从截断态变成全量只多注入约 950 字节
（≈250 token），按 150 次请求、系统提示前缀命中上下文缓存估算，
**整场会话多花不到一分钱**。所以不值得为了省钱让记忆被截断——
截断的代价是「写了但看不到」，那才是真损失。

## 版本记录

- v2（2026-11-05）：补 `maxBytes` 预算算式、实测截断数据与成本估算；
  记录 `maxBytes` 调到 6144 及重启要求。
- v1（2026-11-05）：初版。使用模型：DeepSeek Harness（deepseek-flash）。
  本次消耗 token 未统计。
