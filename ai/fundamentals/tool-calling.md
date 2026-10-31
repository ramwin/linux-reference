# AI 是怎么知道有哪些工具的?

```{contents}
```

## 引子: 一个自然的疑问

用 Kimi Code、Claude Code 这类 CLI 的时候, 你会看到 AI 一会儿 `Read` 一个文件, 一会儿跑一条 `Bash` 命令, 一会儿又去 `WebSearch`。一个自然的疑问是:

> **AI 是怎么知道自己有哪些工具可以用的? 难道 Linux 下的每个命令——`ls`、`grep`、`awk`、`sed`……——都通过一个接口注册到服务器上去了吗?**

答案是: **不是**。而且真相比"注册命令"有意思得多:

> **模型自己一个工具都没有。工具清单是宿主程序(CLI)在每一次请求时, 作为报文的一部分发给模型 API 的; 模型回复的也不是执行结果, 而是"我想调用某某工具、参数是某某"的一段结构化文本; 真正的执行发生在你的本机, 只有执行的输出会被再次发回给模型。**

下面拆开讲, 最后还有用 Kimi Code 自己的会话日志做的实测。

## 一、模型本身没有"工具"这个概念

大模型 API 的本质是一个**文本进、文本出**的函数。你给它一段对话历史, 它续写下一段。它不感知自己的运行环境, 不知道自己在哪台机器上, 也不知道机器上装了什么——它连"现在是几点"都不知道, 除非你在提示词里告诉它。

所以"AI 知道有哪些工具"这句话, 严格说是**宿主程序知道有哪些工具, 并且每次请求都把这个清单告诉模型**。

## 二、工具清单: 每次请求都发一遍

现在主流的模型 API (Anthropic、OpenAI、Kimi 等)都支持 **tool use / function calling**: 请求体里除了 `messages`, 还有一个 `tools` 字段, 每个工具是一段 JSON Schema 声明:

```json
{
  "model": "kimi-for-coding",
  "messages": [{"role": "user", "content": "看看 README 里写了什么"}],
  "tools": [
    {
      "name": "Read",
      "description": "Read a text file from the local filesystem...",
      "input_schema": {
        "type": "object",
        "properties": {
          "path": {"type": "string", "description": "Path to the text file..."}
        },
        "required": ["path"]
      }
    }
  ]
}
```

模型读到这份清单后, 如果决定要用工具, 它的回复**不是自然语言**, 而是一个结构化的调用请求:

```json
{"type": "tool_use", "name": "Read", "input": {"path": "/home/wangx/README.md"}}
```

宿主程序收到后, 在**本地**执行这个工具, 把结果作为一条新消息拼进对话历史, 再次请求模型——如此循环, 直到模型给出最终回复:

```
        ┌───────────────── 你的电脑 (宿主: kimi CLI) ─────────────────┐
        │                                                           │
  你 ──▶│  拼请求: system prompt + 工具清单 + 对话历史                 │──▶ 模型 API (服务器)
        │                                                           │
        │◀── 模型回复: "调用 Read, path=README.md"                    │
        │                                                           │
        │  本地执行 Read, 拿到文件内容                                 │
        │                                                           │
        │  再拼请求: …… + 工具执行结果                                │──▶ 模型 API
        │                                                           │
        │◀── 模型回复: "README 里写的是……"                           │
        └───────────────────────────────────────────────────────────┘
```

要点:

1. **每次请求都带全量工具清单**。模型是无状态的, 它没有"记住"上一轮有哪些工具, 所以宿主每一轮都得重新发。
2. **工具的描述(说明书)也一起发**。`description` 字段写清楚这个工具干什么、参数什么含义——模型就是靠读这份"说明书"决定什么时候用哪个工具的。工具写得好不好用, 一半取决于这份说明书写得好不好。
3. **模型只负责"选"和"填参数", 执行永远在宿主这边**。这也是为什么同一个模型, 套不同的宿主( kimi CLI / Claude Code / Cursor ), 能力看起来完全不同——工具是宿主给的。

## 三、本机实测: 抓 Kimi Code 自己的请求

Kimi Code 的会话日志(`~/.kimi-code/sessions/<工作区>/<会话>/agents/main/wire.jsonl`)完整记录了发给 API 的请求。解析本次写作会话的日志, 可以看到真实发出的工具清单:

- 本次会话一共声明了 **27 个工具**: `Agent`, `AskUserQuestion`, `Bash`, `CronCreate`, `Edit`, `EnterPlanMode`, `FetchURL`, `GetGoal`, `Glob`, `Grep`, `Read`, `Skill`, `TaskList`, `TaskOutput`, `TaskStop`, `TodoList`, `WebSearch`, `Write` 等;
- 这 27 个工具的 JSON Schema 序列化后约 **80 KB**——也就是说, 每一次请求都有约 80 KB 是工具清单, 这还不包括 system prompt 和对话历史;
- 其中 `Bash` 工具的 `description` 开头是这样的(节选):

```json
{"name": "Bash",
 "description": "Execute a `bash` command. Use this for shell semantics — pipes, env, processes, git, package managers, build/test runners, anything genuinely interactive or multi-step.\n\n**Translate these to a dedicated tool instead:**\n- `cat` / `head` / `tail` (known path) → `Read`\n- `sed` / `awk` (in-place edit) → `Edit` ..."}
```

注意看这份说明书写得多细: 它甚至教模型"`cat` 场景请改用 `Read`"——这就是"AI 知道该用哪个工具"的全部秘密: **不是注册, 是每次请求里附带的说明书**。

## 四、那 Linux 命令呢? AI 怎么"会"用 `awk`?

回到引子的问题。Linux 命令**没有任何一个**被注册给服务器。真相分三层:

| 层 | 内容 |
|---|---|
| 工具层 | AI 只知道有 `Bash` 这**一个**工具: "给我一个字符串, 我在 shell 里跑, 把输出还给你" |
| 知识层 | `ls -l` 怎么写、`awk '{print $1}'` 什么意思, 这些全是模型从**训练数据**里学到的, 就像它"会" Python 一样——是脑子里的知识, 不是接口注册的 |
| 执行层 | 命令字符串只是 `Bash` 工具的一个**参数**, 在你的本机执行; 发给服务器的只有命令文本和执行输出 |

所以"难道每个命令都发给服务器吗"——某种意义上是的, 但方式和你想的相反: **不是注册, 而是每次用到时, 作为参数文本捎过去; 执行结果再作为文本捎回去。** 模型对 Linux 的"熟练", 来自训练, 不来自注册表。

这也解释了一个常见现象: AI 偶尔会编造不存在的命令或参数(比如给 `grep` 发明一个 `--fast` 选项)——因为它用的是"记忆里的 Linux", 不是你机器上真实安装的 Linux。严谨的宿主会在工具说明里写"不确定就先跑 `which <command>` 确认", 你能在 Kimi Code 的 `Bash` 工具描述里看到这句话。

## 五、工具从哪来: 内置、MCP、插件、skill

既然工具是宿主声明的, 那宿主的工具清单又是哪来的? 以 Kimi Code / Claude Code 这一类 Agent 为例:

| 来源 | 例子 | 说明 |
|---|---|---|
| 内置工具 | `Read` / `Edit` / `Bash` / `Grep` | CLI 自带, 每次请求固定声明 |
| MCP 服务 | 数据库查询、内部系统 | 宿主连接 MCP server, 把它暴露的工具**翻译成同样的 JSON Schema** 注入清单, 见 [MCP: AI 应用的 "USB-C" 接口](./mcp.md) |
| 插件 | DSH 插件 | 可执行代码, 能往注册表里动态加工具, 见 [DSH 插件与 Claude Skill 的区别](../tools/plugin-vs-skill.md) |
| skill | `SKILL.md` | **不是工具**, 只是提示词, 影响模型怎么决策, 不新增工具 |

不管哪条路径, 最终都殊途同归: 变成 `tools` 字段里的一段 JSON Schema, 随请求发给模型。

## 六、常见误解澄清

| 误解 | 真相 |
|---|---|
| 工具是在服务器上执行的 | 不是。执行在宿主(你的电脑), 服务器上的模型只生成"调用意图"文本 |
| AI 能访问我的文件是因为模型有权限 | 不是。是本地 CLI 进程有你的权限, 模型只是让 CLI 去读 |
| 工具是一次性注册、模型记住的 | 不是。模型无状态, 工具清单每次请求重发一遍 |
| Linux 命令是通过接口注册给 AI 的 | 不是。AI 只有 `Bash` 一个工具, 命令知识来自训练数据 |
| 换一个宿主, 工具还在 | 不在。工具是宿主编的, 换宿主就换了一套工具清单 |

## 本文写作的额度消耗

这篇文章从讨论、查证官方文档到成稿, 全程由 Kimi Code 完成。按本次会话日志(`wire.jsonl`)中的 usage 记录统计(去除连续重复的日志条目), 截至提交前:

| 项目 | token 数 |
|---|---|
| 输入(非缓存) | 约 45,700 |
| 输入(缓存读取) | 约 486,900 |
| 输出 | 约 6,900 |

缓存命中占大头: 工具清单 + system prompt 这种每轮重复的内容走了 prompt cache, 实际计费按各平台缓存费率折算, 远低于全量输入的价格。这也顺带验证了本文的观点——那 80KB 的工具清单确实每一轮都在发往服务器, 只是大部分走了缓存。查看自己额度的方式见下文参考资料。

## 变更记录

| 日期 | 变更 |
|---|---|
| 2026-10-26 | 初稿: 工具清单随请求发送的机制、Kimi Code 实测(27 个工具 / 80KB schema)、Linux 命令三层拆解 |

## 参考资料

- [Kimi Code 官方文档: Slash Commands](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/slash-commands.html) — `/usage` 查看 token 用量与额度
- [Kimi Code 官方文档: Membership](https://www.kimi.com/code/docs/en/kimi-code/membership.html) — 额度规则、5 小时滚动窗口、Console 查余额
- [Anthropic API: Tool use](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview) — `tools` 字段与 `tool_use` 回复格式
- 本机实测数据: `~/.kimi-code/sessions/*/agents/main/wire.jsonl` — Kimi Code 会话的完整请求/响应日志
