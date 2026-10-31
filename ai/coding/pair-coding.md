# Kimi Code + Claude Code (DeepSeek) 结对编程: 一个开发, 一个审查

```{contents}
```

## 为什么让两个不同的模型结对

单独用一个模型开发,最大的问题不是它不够强,而是**它会自我认可**:同一个模型写的代码,自己再看一遍,容易沿着同样的思路漏掉同类错误——错误的假设、被忽略的边界条件,第一遍没发现,第二遍大概率也发现不了。

把 Kimi Code 和 Claude Code(跑 DeepSeek 模型)凑成一对,各司其职:

| 理由 | 说明 |
|------|------|
| **盲点互补** | 两个厂商的训练数据、工具链、思维习惯不同,交叉审查的命中率远高于自我复查 |
| **成本可控** | 审查是"读多写少"的活,DeepSeek V4 Flash 输出参考价 $0.28/M tokens,便宜的一方正好干这个 |
| **角色隔离** | 审查方只读不写,天然不会和开发方改同一行代码打架;"写"和"评"的责任分开,问题清单喂回开发方,闭环清晰 |

分工:

| 角色 | 工具 | 模型 | 动作 |
|------|------|------|------|
| 开发 | Kimi Code CLI | kimi-for-coding | 改文件、跑测试、提交 |
| 审查 | Claude Code | deepseek-v4-flash | 只读 git diff,输出问题清单 |

```{note}
下文中的 "Claude Code" 均指接了 DeepSeek 后端的 Claude Code CLI。两款工具都是终端里的编码 Agent,自带文件读写、命令执行、多轮决策能力,结对不需要任何额外的框架。
```

## 环境准备

### 1. 安装 Kimi Code CLI

Kimi Code CLI 是 Moonshot 开源的终端编码 Agent,命令是 `kimi`,通过 npm 安装:

```bash
# 国内网络先切镜像, 已有镜像可跳过
npm config set registry https://registry.npmmirror.com
npm install -g @moonshot-ai/kimi-code

# OAuth 登录, 会打印一个网址和验证码, 浏览器确认即可
kimi login
```

验证安装:

```bash
kimi -p "用一句话介绍你自己"
```

`-p`(prompt 模式)是后续所有自动化的基础:不进入交互界面,执行完一条指令就退出,并且自动批准文件读写等常规操作,适合脚本驱动。

### 2. 安装 Claude Code 并接入 DeepSeek

```bash
npm install -g @anthropic-ai/claude-code
```

DeepSeek 提供了 Anthropic 兼容端点,Claude Code 不需要改代码,只改几个环境变量即可接入(2026-06-23 起 DeepSeek 官方发布了集成指南)。推荐写进 `~/.claude/settings.json` 的 `env` 块,CLI 和 VS Code 扩展共用:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "<你的 DeepSeek API Key>",
    "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "786432"
  }
}
```

几个关键点:

| 配置 | 说明 |
|------|------|
| `ANTHROPIC_BASE_URL` | 必须是 `https://api.deepseek.com/anthropic`,`/anthropic` 后缀不能少,也不要加 `/v1`(会拼成 `/v1/v1/messages` 报 404) |
| `ANTHROPIC_AUTH_TOKEN` | 填 DeepSeek 的 API Key,**不是** Anthropic 的 |
| `deepseek-v4-pro[1m]` | 主力模型;`[1m]` 后缀申请 1M 上下文窗口,Claude Code 会剥掉后缀再发给 DeepSeek,建议保留 |
| `deepseek-v4-flash` | 轻量模型,映射给 Haiku 档和子代理,审查用它足够 |

```{warning}
`deepseek-chat` / `deepseek-reasoner` 这两个旧模型名已于 **2026-07-24 退役**,请求会报 `404 model not found`。网上老教程的配置记得换成 `deepseek-v4-pro[1m]` / `deepseek-v4-flash`。
```

```{warning}
API Key 不要进 git:如果 `settings.json` 会被提交,把 `env` 块挪到 `~/.claude/settings.local.json`(本地文件,不进仓库),或者直接在 shell 里 `export ANTHROPIC_AUTH_TOKEN=...`。
```

验证:进入 `claude` 交互界面跑 `/status`,确认 Base URL 显示 `api.deepseek.com/anthropic`;再跑一句 `claude -p "说一句你好"`。

## 结对的核心规则

动手之前先立三条规矩,它们是后面所有工作流的地基:

1. **同一时刻只有一个 Agent 改文件**。两个 Agent 同时写同一个工作区,互相覆盖是必然结局。
2. **审查方只读**。审查命令里显式限制工具白名单(见下文 `--allowedTools`),从机制上保证它改不了东西。
3. **审查的对象永远是 git diff**。审查方只看"这次改了什么",不看整个仓库——上下文小、速度快、意见聚焦;也避免审查方被既有代码带偏。

在这个基础上,有串行和并行两种组织方式:

- **串行(推荐入门)**:开发方改完提交,审查方审最后一次提交,问题喂回开发方修复,循环。简单可靠,一次只有一个 Agent 在工作。
- **并行(进阶)**:用 `git worktree` 给每个 Agent 一个独立工作区,开发在主区,审查在另一个 worktree 读 diff。适合审查要花很长时间的大改动,后面"进阶玩法"再展开。

## 方式一: 设计 + 评审(先定方案再动手)

开发之前,先让一方出设计、另一方挑刺,这是性价比最高的检查——设计阶段的漏洞改起来只要改文档,代码阶段改起来要动真金白银。

**终端 A(Kimi 出设计):**

```text
你是资深架构师。任务: {任务描述}
请输出一份设计文档, 保存到 docs/design-{主题}.md, 内容包括:
1. 方案概述与备选方案对比
2. 关键数据结构 / 接口定义
3. 边界情况与异常处理策略
4. 对现有代码的影响面
```

**终端 B(Claude Code 评审设计):**

```bash
claude -p "你是设计评审员, 只评审 docs/design-{主题}.md, 不要修改任何文件。
找出设计漏洞: 性能瓶颈、数据一致性问题、安全风险、影响面遗漏、可维护性问题。
每条意见给出文档中的出处, 按严重程度分级。" \
  --dangerously-skip-permissions \
  --allowedTools "Read,Grep,Glob"
```

把评审意见贴回终端 A:"按以下意见修订设计:..."。来回一到两轮,方案就比单模型自说自话扎实得多。

## 方式二: 开发 + 审查(手动结对, 两个终端)

最直观的结对:两个终端并排,一个写一个查。

**终端 A(Kimi 开发):**

```text
你是资深开发者。任务: {任务描述}
流程:
1. 先浏览相关代码, 说明你的实现方案
2. 按方案实现, 改动保持最小
3. 运行相关测试确认通过
完成后停下, 不要提交, 等我的下一步指令。
```

开发完成后,你手动提交(提交动作留在人手里,是关键的检查点):

```bash
git add -A
git commit -m "feat: {任务描述}"
```

**终端 B(Claude Code 审查):**

```bash
claude -p "你是严格的代码审查员。审查最后一次提交 (git show HEAD), 不要修改任何文件。
规则:
1. 每条问题必须给出 文件:行号 证据
2. 按严重程度分级: 阻断(必须修) / 建议(应该修) / 观察(了解即可)
3. 关注: 边界条件、错误处理、资源泄漏、并发问题、测试覆盖
4. 只报确实存在的问题, 不写客套话" \
  --dangerously-skip-permissions \
  --allowedTools "Read,Grep,Glob"
```

审查输出通常是一份带 `文件:行号` 的问题清单。**把清单原样贴回终端 A**,补一句"按以上意见逐条修复",Kimi 会对照着改。改完再提交、再审,循环:

```{mermaid}
sequenceDiagram
    participant K as 终端A: Kimi (开发)
    participant G as Git
    participant C as 终端B: Claude Code (审查)
    K->>G: 实现并提交
    G->>C: git show HEAD
    C-->>K: 问题清单 (文件:行号 + 分级)
    K->>G: 修复并提交
    G->>C: 新一轮 diff
    C-->>K: 通过 ✓
```

> 两个终端各开一个 tmux 窗口很顺手;不想贴来贴去的话,方式三把它自动化。

## 方式三: 全自动结对(脚本驱动)

两个 CLI 都支持无头模式(`kimi -p` / `claude -p`),所以"开发 → 提交 → 审查 → 修复"整条链路可以写成一个脚本,人在旁边只看结果。

```bash
#!/usr/bin/env bash
# pair.sh — Kimi 开发 + Claude Code (DeepSeek) 审查, 循环直到审查通过
# 用法: ./pair.sh "任务描述"
set -euo pipefail

TASK="${1:?用法: ./pair.sh \"任务描述\"}"
MAX_ROUNDS="${MAX_ROUNDS:-3}"

echo "==> [1] Kimi 开发: $TASK"
kimi -p "你是资深开发者, 任务: $TASK
- 先读相关代码再动手, 改动保持最小
- 改完运行相关测试, 保证通过
- 不要执行 git commit, 提交由脚本处理"

echo "==> [2] 提交改动"
git add -A
git commit -m "dev(kimi): $TASK"

for round in $(seq 1 "$MAX_ROUNDS"); do
  echo "==> [3] 第 $round 轮审查 (Claude Code + DeepSeek)"
  claude -p "你是严格的代码审查员, 只审查下面的 diff, 不要修改任何文件。
规则:
1. 每条问题必须给出 文件:行号 证据
2. 按严重程度分级: 阻断(有 bug 或安全风险) / 建议(值得改) / 观察(了解即可)
3. 只报告确实存在的问题, 不写客套话
4. 最终只输出一个 JSON 对象, 不要 markdown 代码块:
{\"findings\": [{\"file\": \"...\", \"line\": 1, \"level\": \"阻断\", \"description\": \"...\"}]}
没有问题则输出 {\"findings\": []}

diff:
$(git show --format=fuller HEAD)" \
    --output-format json \
    --dangerously-skip-permissions \
    --allowedTools "Read,Grep,Glob" > /tmp/review.json

  # 从 claude 的 JSON 输出中提取"必须处理"的问题, 生成反馈
  python3 - <<'PY' > /tmp/feedback.txt
import json
outer = json.load(open("/tmp/review.json"))
text = outer.get("result", "")
i, j = text.find("{"), text.rfind("}")
findings = json.loads(text[i:j+1]).get("findings", []) if i >= 0 else []
serious = [f for f in findings if f.get("level") in ("阻断", "建议")]
if not serious:
    print("PASS")
else:
    for f in serious:
        print(f"[{f['level']}] {f['file']}:{f['line']} — {f['description']}")
PY

  if grep -q '^PASS$' /tmp/feedback.txt; then
    echo "==> 审查通过, 共 $round 轮"
    exit 0
  fi

  echo "==> [4] 问题清单:"
  cat /tmp/feedback.txt
  echo "==> 交回 Kimi 修复"
  kimi -p "代码审查发现以下问题, 逐条修复:
$(cat /tmp/feedback.txt)
修复后运行相关测试, 不要执行 git commit"
  git add -A
  git commit -m "fix(kimi): 第 $round 轮审查问题修复"
done

echo "==> 达到最大轮数 $MAX_ROUNDS, 仍有问题待处理, 见 /tmp/feedback.txt"
```

逐段拆解:

1. **`kimi -p` 无头开发**:prompt 模式不弹交互界面,自动批准常规操作,跑完退出。指令里明确"不要 commit",把提交权留给脚本;
2. **提交**:人(或脚本)提交,Kimi 的改动变成一个干净的 diff,供下一环审查;
3. **`claude -p` 无头审查**:三个参数是安全关键——`--dangerously-skip-permissions` 免去逐条确认,`--allowedTools "Read,Grep,Glob"` 把工具白名单锁成只读,`--output-format json` 让输出可被程序解析;
4. **解析 JSON**:claude 的 json 输出是 `{"result": "..."}` 结构,审查清单在 `result` 字段里,用 python 提取;只把"阻断/建议"两级问题喂回 Kimi,"观察"级不阻塞;
5. **循环**:修复后重新提交、再审,直到 `PASS` 或超过 `MAX_ROUNDS`。

```{warning}
`kimi -p` 模式会自动批准文件读写等常规操作,等于把工作区交给了模型。脚本只在你信任的目录(比如一个专门的项目仓库)里跑,别拿去对 `~` 或生产服务器用。
```

## 审查 prompt 怎么写才有效

审查质量九成取决于 prompt。上面两个模板里藏着四条经验:

1. **强制证据**:"每条问题必须给出 文件:行号"。没有这个要求,模型会输出"整体结构可以优化"之类的空话;有行号,你(和修复方)才能逐条核实——审查方也可能说错,行号让它说的话可证伪;
2. **分级**:阻断 / 建议 / 观察。分级既给修复方排了优先级,也让脚本能只把高级别问题喂回去,避免在鸡毛蒜皮上空转;
3. **禁止客套**:"只报确实存在的问题,不写客套话"。模型默认有迎合倾向,不约束它,一半的输出是"整体完成得很好,建议..."
4. **只审 diff**:"审查下面的 diff",把范围钉死。范围越小,意见越具体;顺便省 token。

如果审查意见和你的判断冲突,当场追问它:"给出这个结论的依据"。两个模型互相制衡,最后的判断权在你。

## 进阶玩法

### git hook: 提交即审查

把审查挂到 `post-commit` hook,每次 Kimi 提交完自动触发:

```bash
# .git/hooks/post-commit
#!/usr/bin/env bash
claude -p "你是严格的代码审查员, 审查最后一次提交 (git show HEAD), 不要修改任何文件。
每条问题给出 文件:行号 证据, 按 阻断/建议/观察 分级, 只报确实存在的问题。" \
  --dangerously-skip-permissions \
  --allowedTools "Read,Grep,Glob"
```

适合有审查意识的仓库:每笔提交都有一份独立的、来自另一个模型的意见。

### 交互式深审: /code-review

无头模式的审查胜在自动化,但讨论感弱。大改动、拿不准的改动,开一个 Claude Code 交互会话,让它审查当前 diff,针对每条意见追问"为什么""有没有反例",把审查变成对话。修起来慢,但适合关键路径。

### worktree 并行: 一个写一个审, 互不阻塞

开发要跑很久时,可以让审查方在另一个 worktree 上并行读 diff:

```bash
git worktree add ../project-review HEAD~1
cd ../project-review
claude -p "审查 ../project 最后一次提交 (git -C ../project show HEAD), 不要修改任何文件" \
  --dangerously-skip-permissions --allowedTools "Read,Grep,Glob"
```

两个 Agent 各有各的工作区,物理上不可能互相覆盖;开发不被打断,审查意见开发完再统一处理。

### 角色互换: 防止盲区固化

长期固定"Kimi 写、DeepSeek 审",等于默认了 Kimi 的开发水平总是对的。每过一段时间交换一次角色(DeepSeek 开发、Kimi 审),两边的问题都会暴露出来,也顺带比较两个模型在你项目上的真实水平。

## 常见坑

| 坑 | 现象 | 处理 |
|----|------|------|
| 两个 Agent 同时改文件 | 改动互相覆盖,git 状态混乱 | 严格遵守串行;要并行就用 worktree |
| 审查全是空话 | "整体不错,建议优化" | prompt 强制 文件:行号 + 禁止客套 |
| 互相认同错误 | 修复方照单全收错误意见 | 逐条核实行号;拿不准让审查方给依据 |
| DeepSeek 报 404 model not found | 旧教程的 `deepseek-chat` 配置 | 换成 `deepseek-v4-pro[1m]` / `deepseek-v4-flash` |
| DeepSeek 工具调用偶发失败 | diff 编辑偶尔重试、丢工具调用 | 这是已知现象(成功率低于官方 Claude),审查只用只读工具影响很小;开发方仍用 Kimi |
| 上下文超限报 400 | DeepSeek 上下文窗口较小 | 设置 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432`;审查只喂 diff 不喂全仓库 |
| API Key 泄漏 | settings.json 被 git 提交 | key 放 `settings.local.json` 或环境变量 |
| 无头模式误操作 | `kimi -p` 自动批准改动 | 只在受信任的目录跑;提交动作保留在脚本/人手里 |

## 总结

- **分工**:Kimi Code 写代码、Claude Code(DeepSeek)审 diff,审查方永远只读;
- **闭环**:开发 → 提交 → 审查 → 问题清单喂回开发 → 再审查,直到通过;
- **自动化**:两个 CLI 的无头模式(`kimi -p` / `claude -p --output-format json`)让整个闭环可以脚本化,`post-commit` hook 让审查零成本;
- **边界**:审查意见要带 文件:行号 证据,最后判断权在你手里。

## 参考资料

- [Kimi Code CLI 官方速查表](https://www.kimi.ai/resources/kimi-code-cheat-sheet)([中文版](https://www.kimi.ai/zh-hans/resources/kimi-code-cheat-sheet))
- [DeepSeek 发布官方 Claude Code 集成指南(2026-06-23)](https://deepseekv4pro.com/news/deepseek-june23-claude-code-official-integration)
- [DeepSeek V4 接 Claude Code:从零到跑通配置教程](https://cloud.tencent.cn/developer/article/2695549)(含旧模型退役说明)
- [awesome-deepseek-agent:Claude Code 接入 DeepSeek 中文文档](https://github.com/miaomiao1992/awesome-deepseek-agent/blob/main/docs/claude_code.zh-CN.md)
- [Kimi 与 Claude CLI 无头模式对比(2026-05)](https://github.com/lythos-labs/lythoskill/blob/8ee925620517b813d44d752e71c05b26c0ee1eb3/cortex/wiki/03-lessons/2026-05-06-kimi-vs-claude-cli-headless-comparison.md)
