# 只有一个 Claude Code: 让多个模型讨论方案和 review 代码

```{contents}
```

上一篇 [Kimi Code + Claude Code 结对编程](./pair-coding.md) 用两个厂商的 CLI 实现"一个开发、一个审查"。这篇回答一个更极端的问题:**如果手里只有一个 Claude Code(DeepSeek 的 key 和模型),怎么让"多个模型"多次讨论出合理方案、review 代码?这样做的意义大不大,还是直接把思考 effort 拉满更好?**

结论先放在前面:

1. **能做**,而且不需要额外工具——同一个 CLI 里用不同的模型档位 + 不同的角色 prompt + 独立会话,就能搭起"圆桌";
2. **意义打折**:同厂商模型的思考方式同源,多样性远不如上一篇的跨厂商结对,主要收益来自"角色分离"和"多轮对抗",而不是"模型不同";
3. **不是二选一**:方案设计和代码审查值得多轮讨论,编码任务直接把 effort 拉满更划算。

## 手里有什么牌

| 资源 | 说明 |
|------|------|
| 两个档位的模型 | `deepseek-v4-pro[1m]`(强/慢/贵)和 `deepseek-v4-flash`(快/便宜)。它们是**两个不同的模型**,可以扮演不同角色 |
| `claude -p` 无头模式 | 每次调用是全新会话、互不记得对方,天然适合"多个独立人格" |
| `--model` 切换 | 同一 CLI 指定不同模型:`claude -p "..." --model deepseek-v4-flash` |
| effort 等级 | `CLAUDE_CODE_EFFORT_LEVEL`,low ~ max,控制单次推理的思考深度(DeepSeek 官方指南推荐 `max`) |

"多模型讨论"的搭建方式就是这三样东西的组合:**模型档位 × 角色 prompt × 独立会话**。

## 先想清楚:多样性从哪来

这是整件事的成败关键。两个模型能互相查漏,前提是它们的**盲区不重叠**。盲区的来源:

| 组合 | 盲区重叠度 | 互相查漏效果 |
|------|-----------|-------------|
| 跨厂商(Kimi vs DeepSeek) | 低——训练数据、对齐方式、工具链都不同 | 强 |
| 同厂商 pro vs flash | 中高——大概率同族架构、同源数据(flash 常是 pro 的小参数/蒸馏版) | 中 |
| 同一个模型、两个会话 | 极高——完全同一个人 | 弱,只有"角度"不同 |

所以诚实地说:**只有一个 DeepSeek 时,别指望换档位能带来跨厂商那样的查漏效果**。多轮讨论在这里的真正价值来自另外两个机制:

1. **角色分离打破"生成即定稿"**:模型生成方案时会自我确认(爱上自己的第一个想法);让它换一个"批评家"身份、独立会话里重新读一遍,等于强制它从反面思考;
2. **多轮增量信息**:第 N 轮的输入包含第 N-1 轮的批评,模型能看到自己先前没意识到的点。轮与轮之间有新信息注入,讨论才有意义;没有新信息,第二轮开始就是复读机。

记住这两条,就能理解下面每个做法的边界。

## 方式一: 设计阶段的多角色讨论(性价比最高)

方案设计是"多解、需权衡"的问题,恰好是多轮讨论最擅长的地方。三轮制:

```{mermaid}
flowchart LR
    A["第1轮: 架构师<br/>(pro) 出两个候选方案"] --> B["第2轮: 批评家<br/>(pro, 新会话) 逐个攻击"]
    B --> C["第3轮: 裁决者<br/>(pro, 新会话) 综合修订"]
```

**第 1 轮——出方案。** 关键技巧:要求出**两个**候选方案,而不是一个。只有一个方案时,后面的批评会变成"修补";有两个方案,批评才能变成"比较"。

```bash
claude -p "你是资深架构师。任务: {任务描述}
要求:
1. 给出两个明显不同的候选方案(比如不同的技术选型), 各写一节
2. 每个方案明确写出: 优势、劣势、放弃的东西
3. 输出保存到 docs/design-candidates.md
不要急着选, 你的任务是摆出选项。" \
  --model deepseek-v4-pro[1m] \
  --dangerously-skip-permissions --allowedTools "Write,Read"
```

**第 2 轮——找茬。** 换一个全新会话(`-p` 每次都是新的),换一个角色,让批评家只负责攻击:

```bash
claude -p "你是以毒舌著称的架构评审员。阅读 docs/design-candidates.md, 你的任务是找问题, 不是夸人。
规则:
1. 对每个方案: 找出 3 个最重要的漏洞或风险
2. 每条意见必须引用文档中的具体表述
3. 按严重程度分级: 致命 / 重要 / 建议
4. 禁止输出'整体不错'这类没有信息量的话
输出保存到 docs/design-critique.md" \
  --model deepseek-v4-pro[1m] \
  --dangerously-skip-permissions --allowedTools "Write,Read"
```

**第 3 轮——裁决。** 再来一个新会话,给它前两轮的产物,让它综合:

```bash
claude -p "阅读 docs/design-candidates.md 和 docs/design-critique.md。
综合双方观点: 逐条裁决批评是否成立(成立/不成立/部分成立, 各给一句理由),
然后给出最终方案(可以是某个候选的修订版, 也可以是两者的混合)。
输出保存到 docs/design-final.md" \
  --model deepseek-v4-pro[1m] \
  --dangerously-skip-permissions --allowedTools "Write,Read"
```

```{note}
三轮都用 `deepseek-v4-pro[1m]` 是故意的:批评和裁决都需要能力,用 flash 当批评家只会产出低质量的挑刺。flash 的正确位置是流水线里的杂活——比如把最终方案转成任务清单、写 commit message,便宜又快。
```

设计文档落在 `docs/` 里是刻意为之:每一轮的产物都以文件形式沉淀,下一轮可以精确引用,人也可以随时介入检查——"讨论"没有黑箱。

## 方式二: 代码 review 的双审查者叠加

单模型自我 review 的最大问题是思路惯性:写代码时没想过的边界条件,再看一遍也常常想不起来。双审查者的做法是**换档位、换视角、审同一份 diff**:

```bash
# 审查者1: pro, 盯正确性
claude -p "你是严格的代码审查员, 只审查下面的 diff, 不要修改任何文件。
关注: 边界条件、错误处理、资源泄漏、并发问题。
每条问题给出 文件:行号 证据, 按 阻断/建议/观察 分级。
只输出 JSON: {\"findings\": [...]}

diff:
$(git show HEAD)" \
  --model deepseek-v4-pro[1m] \
  --output-format json \
  --dangerously-skip-permissions --allowedTools "Read,Grep,Glob" > review-correct.json

# 审查者2: flash, 盯性能与可维护性
claude -p "你是性能与可维护性审查员, 只审查下面的 diff, 不要修改任何文件。
关注: 不必要的复杂度、重复代码、性能陷阱、命名与结构。
每条问题给出 文件:行号 证据, 按 阻断/建议/观察 分级。
只输出 JSON: {\"findings\": [...]}

diff:
$(git show HEAD)" \
  --model deepseek-v4-flash \
  --output-format json \
  --dangerously-skip-permissions --allowedTools "Read,Grep,Glob" > review-maint.json
```

然后用一段小脚本合并去重(两个审查者可能发现同一个问题):

```python
import json

def extract(path):
    outer = json.load(open(path))
    text = outer.get("result", "")
    i, j = text.find("{"), text.rfind("}")
    return json.loads(text[i:j+1]).get("findings", []) if i >= 0 else []

seen, merged = set(), []
for f in extract("review-correct.json") + extract("review-maint.json"):
    key = (f.get("file"), f.get("line"), f.get("description")[:40])
    if key not in seen:
        seen.add(key)
        merged.append(f)

print(json.dumps({"findings": merged}, ensure_ascii=False, indent=2))
```

这里 pro 管正确性(最需要能力)、flash 管性能/维护性(相对机械,省一半钱)的分工是有意的:把贵模型用在刀刃上,便宜模型打配合。审查者超过两个之后边际收益骤降——两个视角通常已经覆盖了"独立"的主要部分,第三个开始与前两个重叠。

## 方式三: 把"讨论"自动化

上一篇文章的 `pair.sh` 是跨 CLI 的;同一个思路完全可以用一个 CLI 的两个模型实现:

```bash
#!/usr/bin/env bash
# debate.sh — 提案方与反对方多轮辩论, 直到收敛或达到轮数上限
# 用法: ./debate.sh "议题描述" [最大轮数]
set -euo pipefail

TOPIC="${1:?用法: ./debate.sh \"议题描述\"}"
ROUNDS="${2:-3}"

echo "==> 提案方 (deepseek-v4-pro) 出方案"
claude -p "你是架构师, 就以下议题给出完整方案: $TOPIC
只输出方案正文。" \
  --model deepseek-v4-pro[1m] \
  --dangerously-skip-permissions --allowedTools "Read" > proposal.txt

for round in $(seq 1 "$ROUNDS"); do
  echo "==> 第 $round 轮: 反对方批评"
  claude -p "你是评审员。阅读下面的方案, 找出最重要的 3 个问题。
每条问题必须: 引用方案原文 + 说明后果 + 给出改进方向。
不要客套, 没有问题的部分不要评论。

方案:
$(cat proposal.txt)" \
    --model deepseek-v4-pro[1m] \
    --dangerously-skip-permissions --allowedTools "Read" > critique.txt

  echo "==> 第 $round 轮: 提案方修订"
  claude -p "针对以下批评逐条回应并修订方案。
批评可能正确也可能错误, 你要有自己的判断, 不能照单全收。
输出修订后的完整方案:

批评:
$(cat critique.txt)" \
    --model deepseek-v4-pro[1m] \
    --dangerously-skip-permissions --allowedTools "Read" > proposal.txt
done

echo "==> 最终方案已写入 proposal.txt"
```

两个要点:

- **每轮批评只让提 3 个问题**——强迫它挑最重要的说,避免输出一大页不痛不痒的意见;
- **修订方"不能照单全收"**——防止批评方说错、修订方盲目跟进,两人一起跑偏。让模型明确知道:对方的输出是"待检验的观点",不是"指令"。

```{warning}
同一模型扮演正反两方时,它没有"新知识",只有"新角度"。轮数超过 3 之后,批评开始重复、修订开始原地打转——观察 critique.txt 里是否出现重复条目,出现了就该停,加轮数只会烧钱。
```

## 核心问题: 多轮讨论 vs 加大 effort, 哪个值

先厘清两个概念:

- **effort**(`CLAUDE_CODE_EFFORT_LEVEL`)是**单次推理的思考深度**:更长的推理、更充分的权衡,但仍然是"一个人想一次";
- **多轮讨论**是**多次独立的思考**:换身份、换输入、互相攻击,用"次数"换"角度"。

关键在于:**深度思考解决不了自我确认**。一个再深的人也倾向于确认自己的第一想法;而把同一个人放出去隔一会再换个身份审自己,反而常常发现新东西。这是多轮讨论不可被 effort 替代的部分。

但多轮讨论的成本是线性叠加的(N 轮 = N 倍 token),收益在 2-3 轮后骤降。按场景给结论:

| 场景 | 推荐 | 理由 |
|------|------|------|
| 方案设计(多解、需权衡) | 多角色 2-3 轮 + effort=max | 讨论能显式列出候选并对抗权衡;单次深思考容易"爱上第一个方案"。这是多轮最值钱的场景 |
| 明确的编码任务 | effort=max 单跑 | 任务收敛、目标明确,深度推理直接出活;多轮纯属浪费 |
| 代码审查 | 双审查者一次叠加 + effort=max | 审查的收益来自独立视角;两个视角已覆盖主要盲区,第三个开始重复 |
| 探索性研究(方向未定) | 多轮 | 每轮结论作为下轮输入,轮与轮之间有真实增量 |

预算有限时的优先级:**先 effort=max,再上多轮**。因为 effort=max 是一次性成本、对所有场景都有正收益;多轮讨论是倍数成本,只在上面表格的前两个场景里明显回本。

成本感受一下量级:DeepSeek V4 Flash 输出约 ¥4/M tokens(今天起的新价),一次设计讨论(三份文档约 1 万 token 输出)成本以"分"计。便宜到可以随便试——这也是为什么"多讨论几轮"在 DeepSeek 上是个低成本实验,而在按美元计费的模型上要精打细算。

## 常见坑

| 坑 | 现象 | 处理 |
|----|------|------|
| 同模型互认错误 | 批评方附和提案方的错误前提 | prompt 强制"引用原文 + 给依据";裁决轮要求"逐条表态成立/不成立" |
| 轮次多了变复读机 | critique.txt 出现重复条目 | 轮数上限设 3;发现重复就停 |
| 用 flash 当批评家 | 挑的刺质量差,讨论降级 | 批评/裁决用 pro,flash 只做杂活 |
| 讨论没沉淀 | 每轮输出不落文件,下一轮靠脑补 | 每轮写 docs/ 文件,下一轮引用文件 |
| 以为换档位=换脑子 | 期待 pro vs flash 有跨厂商级的互补 | 降低预期:收益主要来自角色分离,不是模型多样性 |
| effort 对第三方模型的效果不透明 | 设了 effort 但 DeepSeek 服务端如何映射不公开 | 以 DeepSeek 官方指南为准(推荐 max),实测对比你的任务 |

## 总结

- **能做**:一个 CLI + 两个档位的模型 + 角色 prompt + 独立会话,就能搭起"圆桌",全程 shell 脚本可自动化;
- **价值边界**:同厂商模型的多样性打折,多轮讨论的主要收益是"角色分离 + 多轮增量",不是"第二个脑子";跨厂商结对(上一篇)仍然是查漏效果更好的方案;
- **取舍**:设计阶段多轮 2-3 轮最值,代码审查双审查者一次叠加,编码任务直接把 effort 拉满;预算有限先拉 effort,再考虑多轮;
- **边界**:超过 3 轮开始复读,两个审查者后开始重叠,flash 不该当批评家——多不等于好。

## 参考资料

- [上一篇: Kimi Code + Claude Code (DeepSeek) 结对编程](./pair-coding.md)
- [DeepSeek 发布官方 Claude Code 集成指南(2026-06-23)](https://deepseekv4pro.com/news/deepseek-june23-claude-code-official-integration)
- [DeepSeek V4 接 Claude Code:从零到跑通配置教程](https://cloud.tencent.cn/developer/article/2695549)
- [awesome-deepseek-agent:Claude Code 接入 DeepSeek 中文文档](https://github.com/deepseek-ai/awesome-deepseek-agent/blob/main/docs/claude_code.zh-CN.md)
- [Du et al., Improving Factuality and Reasoning in Language Models through Multiagent Debate(2023)](https://arxiv.org/abs/2305.14325)
