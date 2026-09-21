# MCP: AI 应用的 "USB-C" 接口

```{contents}
```

上一篇 [从0开始搭建一个 Agent](./agent.md) 里, 工具调用是我们手写的: 自己定义一套 JSON 格式, 自己解析模型的输出, 自己把每个工具对接进循环。这样写出来的 Agent 只有你自己能用——换个 AI 应用, 全部集成代码都要重来。

**MCP (Model Context Protocol, 模型上下文协议)** 解决的就是这个重复造轮子的问题: 它把"AI 应用如何连接外部工具和数据源"这件事标准化成一个开放协议。任何一个工具只要按 MCP 实现一次, 所有支持 MCP 的 AI 应用(Claude、ChatGPT、Cursor、VS Code……)都能直接用它。

学完之后你会: 看懂 MCP 的架构和协议报文, 给 Claude Desktop / Claude Code 接入现成的 MCP 服务, 并能自己动手写一个 MCP 服务跑起来。

## MCP 解决什么问题: 从 M×N 到 M+N

没有 MCP 的时候, 每接入一个工具, 每个 AI 应用都要写一遍对接代码——自己定义调用格式、自己解析参数、自己处理报错。N 个 AI 应用 × M 个工具, 就是 N×M 套集成:

```
                 没有 MCP                          有了 MCP
                                        ┌──────────────────────────┐
   应用A ──┬── 工具1                     │          MCP 协议         │
   应用B ──┼── 工具1   每对组合            │  (统一的工具/数据/提示接口)  │
     ...   │   都要手写一套                └───▲──────────▲───────────┘
   应用A ──┤── 工具2                         │          │
   应用B ──┴── 工具2                     各写一次适配器    各写一次适配器
   N×M 套集成代码                          N 个应用  +  M 个工具
```

MCP 相当于 AI 世界的 USB-C 接口: 插座和插头各标准化一次, 任意组合即插即用。它明显借鉴了 LSP (Language Server Protocol) 的思路——LSP 让编辑器与语言服务器解耦, MCP 让 AI 应用与工具/数据源解耦。

这个协议的来历和几个关键节点:

| 时间 | 事件 |
|---|---|
| 2024-11 | Anthropic 开源 MCP, Claude Desktop 首个接入 |
| 2025-03 | OpenAI 宣布全线接入 (Agents SDK / ChatGPT 桌面版) |
| 2025 年内 | Google、微软 (Copilot / VS Code)、Cursor 等主流工具陆续支持 |
| 2025-12 | Anthropic 将 MCP 捐赠给 Linux 基金会旗下的 Agentic AI Foundation (AAIF), 与 OpenAI 捐赠的 AGENTS.md、Block 捐赠的 goose 并列; 创始成员包括 Anthropic、OpenAI、Block, AWS/Google/微软等任白金成员 |
| 2026-07-28 | 发布迄今最大一次规范修订, 核心是协议层全面**无状态化** |

到今天, MCP 已是事实上的行业标准: 官方注册表里的公开 MCP 服务数以万计, 各语言 SDK 的月下载量以千万计。

## 角色与架构

MCP 把世界分成三个角色:

```
+-----------------------------------------------------------+
|  MCP Host (宿主应用)                                       |
|  Claude Desktop / Claude Code / Cursor / VS Code ...      |
|                                                           |
|   +----------------+      JSON-RPC 2.0     +-----------+  |
|   |  MCP Client    | <------------------> |   MCP     |  |
|   |  (每个 server  |   stdio 或           |  Server   |  |
|   |   一个连接)     |   Streamable HTTP    | (工具/数据) |  |
|   +----------------+                      +-----------+  |
|                                                           |
|   +----------------+                      +-----------+  |
|   |  MCP Client    | <-----------------> |   MCP     |  |
|   +----------------+                      |  Server   |  |
|                                           +-----------+  |
+-----------------------------------------------------------+
```

- **Host**: 你实际使用的 AI 应用, 内置 LLM 和对话界面;
- **Client**: Host 内部的连接器, 每个 MCP Server 对应一个 Client 连接, 负责协议握手和报文收发;
- **Server**: 轻量的能力提供方, 暴露工具、数据、提示模板。它是独立的进程或服务, 用什么语言写都行 (官方 SDK 有 Python / TypeScript, 社区还有 Java、Go、Rust、C# 等)。

Server 与 Client 之间的传输层有两种:

| 传输 | 方式 | 适用场景 |
|---|---|---|
| **stdio** | Host 把 Server 作为子进程拉起, 用标准输入/输出传 JSON-RPC | 本地工具, 最常用, 本篇文章的 demo 用它 |
| **Streamable HTTP** | Server 作为独立 HTTP 服务 (默认路径 `/mcp`), 支持 SSE 流式响应 | 远程共享服务, 多用户, 需要鉴权 |

## 三大原语: Tools / Resources / Prompts

MCP Server 能暴露三类能力, 区别在"由谁决定使用":

| 原语 | 谁决定调用 | 作用 | 例子 |
|---|---|---|---|
| **Tools** (工具) | 模型自动决策 | 可执行的函数, 有副作用 | 查数据库、发消息、创建 issue |
| **Resources** (资源) | 应用/用户决定 | 只读的数据或上下文 | 文件内容、日志、数据库记录 |
| **Prompts** (提示模板) | 用户主动选择 | 预置的提示词模板, 参数化 | "评审这段代码"、“生成周报” |

可以类比成函数调用: Tools 是被调用的函数, Resources 是只读的变量, Prompts 是代码片段模板。

2026-07-28 版规范在此基础上又添了两类官方扩展: **Tasks** (把耗时操作拆成长任务, 客户端可用 `tasks/get` / `tasks/cancel` 管理) 和 **MCP Apps** (Server 下发 HTML 界面, Host 在沙箱 iframe 里渲染, 让工具拥有交互式 UI)。同时废弃了三个早期特性: Roots (用工具参数替代)、Sampling (直接调 LLM API 替代)、Logging (用 stderr / OpenTelemetry 替代)。

## 协议内幕: JSON-RPC 与无状态化

MCP 的报文就是 JSON-RPC 2.0,  methods 固定几个: `tools/call`、`tools/list`、`resources/read`、`prompts/get` 等。真正的大变化发生在 2026-07-28: **协议层从有状态全面转向无状态**。

旧版 (2025-11-25) 调一个工具要先建立会话——先发 `initialize` 握手, 服务器返回 `Mcp-Session-Id`, 之后每个请求都要带上它, 请求被"粘"在签发会话的那台服务器上:

```http
POST /mcp HTTP/1.1
Content-Type: application/json

{"jsonrpc":"2.0","id":1,"method":"initialize",
 "params":{"protocolVersion":"2025-11-25","capabilities":{},
           "clientInfo":{"name":"my-app","version":"1.0"}}}
```

```http
POST /mcp HTTP/1.1
Mcp-Session-Id: 1868a90c-3a3f-4f5b
Content-Type: application/json

{"jsonrpc":"2.0","id":2,"method":"tools/call",
 "params":{"name":"search","arguments":{"q":"otters"}}}
```

新版 (2026-07-28) 把握手和会话整个删掉, 每个请求自包含: 协议版本和客户端信息放在报文 `_meta` 里, HTTP 头带上 `Mcp-Method` / `Mcp-Name` 方便网关路由, 任何一个服务器实例都能独立处理:

```http
POST /mcp HTTP/1.1
MCP-Protocol-Version: 2026-07-28
Mcp-Method: tools/call
Mcp-Name: search
Content-Type: application/json

{"jsonrpc":"2.0","id":1,"method":"tools/call",
 "params":{"name":"search","arguments":{"q":"otters"},
           "_meta":{"io.modelcontextprotocol/clientInfo":
                     {"name":"my-app","version":"1.0"}}}}
```

这对运维是质变: 原来横向扩容要 sticky session + 共享会话存储, 现在一个普通轮询负载均衡器就够; `tools/list` 的响应带 `ttlMs` 缓存声明, 客户端可以像对待 HTTP 缓存一样对待它; 还能按 W3C Trace Context 把整个调用链串进 OpenTelemetry。

注意"无状态"不等于"应用不能有状态"。需要跨调用保持状态的服务器 (比如一个多步的"购物车"工具), 可以学普通 HTTP API 的做法: 由工具显式签发一个句柄 (如 `basket_id`), 模型在后续调用里把它当普通参数传回来。状态从"藏在传输层元数据里"变成"模型可见、可推理、可组合", 这反而是更强大的模式。

本地 stdio 场景几乎不受这次修订影响 (子进程连接本来就是一对一的), 变化主要冲击远程 HTTP 部署。

## 典型用法

围绕 MCP 的开发活动大致三类: **用别人的 Server**、**写自己的 Server**、**部署远程 Server**。

### 用法一: 接入现成的 MCP 服务

官方注册表 (registry.modelcontextprotocol.io) 收录了上万个服务, 数据库 (Postgres/Redis/Mongo)、GitHub、Slack、浏览器自动化、文件系统等应有尽有。以 Claude Desktop 为例, 编辑配置文件:

```json
// ~/.config/Claude/claude_desktop_config.json (Linux)
// macOS 为 ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/wangx/docs"]
    }
  }
}
```

重启后 Claude Desktop 就多了一个能读写 `/home/wangx/docs` 的工具, 模型会在需要的时候自动调用。Claude Code 里用命令行更顺手:

```bash
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem ~/docs
claude mcp list        # 验证连接
```

Cursor / VS Code / Windsurf 的配置是同样的 JSON 结构 (`.cursor/mcp.json` 等), 连远程服务时把 `command/args` 换成 `url` 即可。

### 用法二: 自己写一个 MCP 服务

这是本文的重点。用 Python SDK 写一个最小但完整的 Server, 三种原语各暴露一个。

**环境准备** (需要 Python 3.10+):

```bash
pip install "mcp>=2"
```

```{note}
网上大部分教程写的是 `from mcp.server.fastmcp import FastMCP`——那是 SDK 1.x 的 API。2.x 起 `FastMCP` 已改名为 `MCPServer` (mcp.server.mcpserver 模块), 旧代码要么升级, 要么 `pip install "mcp<2"` 锁定。下面的代码基于 2.x 实测通过。
```

**`server.py`**: 一个工具查磁盘用量, 一个资源放说明文档, 一个提示模板做代码评审:

```python
"""一个最小的 MCP 服务: 演示 tool / resource / prompt 三种原语。"""

import shutil

from mcp.server.mcpserver import MCPServer

mcp = MCPServer("demo")


@mcp.tool()
def disk_usage(path: str = "/") -> str:
    """查询指定路径所在磁盘的使用情况, path 默认为根目录。"""
    usage = shutil.disk_usage(path)
    return (
        f"{path}: 总容量 {usage.total / 2**30:.1f} GiB, "
        f"已用 {usage.used / 2**30:.1f} GiB, "
        f"剩余 {usage.free / 2**30:.1f} GiB"
    )


@mcp.resource("note://readme")
def readme() -> str:
    """demo 服务的说明文档。"""
    return "这是 demo MCP 服务: tool 查磁盘, prompt 生成评审意见。"


@mcp.prompt()
def review_code(code: str) -> str:
    """让模型评审一段代码。"""
    return f"请评审下面的代码, 指出潜在的问题并给出改进建议:\n\n{code}"


if __name__ == "__main__":
    mcp.run()  # 默认 stdio 传输, 由客户端启动并通过标准输入输出通信
```

不到 40 行, 重点只有三处:

1. `@mcp.tool()` 装饰的函数就是工具。函数签名和 docstring 会被自动转成工具的 JSON Schema 和描述, **docstring 一定要写清楚**——模型靠它理解什么时候该调这个工具;
2. `@mcp.resource("note://readme")` 暴露只读资源, URI  scheme 自己定, 也支持 `note://{name}` 这类模板;
3. `@mcp.prompt()` 暴露参数化的提示模板, 用户在客户端里手动选用。

**`client.py`**: 不依赖任何 AI 应用, 直接以子进程方式拉起 server, 走完一遍协议:

```python
"""测试客户端: 以子进程方式拉起 server.py, 走 stdio 调用三个原语。"""

import asyncio

from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


async def main() -> None:
    params = StdioServerParameters(command="python3", args=["server.py"])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            tools = await session.list_tools()
            print("tools:", [t.name for t in tools.tools])

            result = await session.call_tool("disk_usage", {"path": "/"})
            print("disk_usage:", result.content[0].text)

            resource = await session.read_resource("note://readme")
            print("resource:", resource.contents[0].text)

            prompt = await session.get_prompt("review_code", {"code": "x = 1;; print(x)"})
            print("prompt:", prompt.messages[0].content.text)


if __name__ == "__main__":
    asyncio.run(main())
```

运行 (两个文件放同一目录):

```bash
$ python3 client.py
tools: ['disk_usage']
disk_usage: /: 总容量 960.2 GiB, 已用 586.9 GiB, 剩余 324.4 GiB
resource: 这是 demo MCP 服务: tool 查磁盘, prompt 生成评审意见。
prompt: 请评审下面的代码, 指出潜在的问题并给出改进建议:

x = 1;; print(x)
```

看到真实磁盘用量, 说明整条链路是通的: 客户端启动 server 子进程 → JSON-RPC 握手 → 工具调用/资源读取/提示获取。接下来只要把它注册进 Claude Desktop 或 Claude Code:

```bash
claude mcp add demo -- python3 /绝对路径/server.py
```

之后对 Claude 说一句"看看我磁盘还剩多少", 它就会自己调用 `disk_usage` 工具。

调试工具可以用官方 Inspector, 以图形界面浏览和调用 server 的所有原语:

```bash
npx @modelcontextprotocol/inspector python3 server.py
```

### 用法三: 部署远程 MCP 服务

把 `mcp.run()` 的传输换成 Streamable HTTP, Server 就变成了独立 Web 服务:

```python
if __name__ == "__main__":
    # 监听 http://127.0.0.1:8000/mcp, 可用 host/port 参数修改
    mcp.run(transport="streamable-http")
```

客户端配置从 `command/args` 改为 URL 即可接入:

```json
{
  "mcpServers": {
    "demo-remote": {
      "url": "https://mcp.example.com/mcp"
    }
  }
}
```

这正是 2026-07-28 无状态化发挥价值的地方: 多实例部署不再需要会话粘滞, 普通负载均衡 + 按 `Mcp-Method` 头路由即可水平扩展; 响应自带的 `ttlMs` 让网关和客户端可以放心缓存 `tools/list`。对外提供服务时配合 OAuth 2.1 / OIDC 鉴权 (规范专门强化了这一块, 包括动态客户端注册、issuer 校验等), 用户授权后客户端才能调用。

## 安全注意事项

MCP 让 AI 能"动手", 也让风险标准化了:

- **本地 stdio Server 拥有你的全部权限**。它以你的身份跑在你机器上, 装一个来路不明的 MCP Server 等于运行一个来路不明的程序。只装可信来源的, 装前读代码;
- **工具描述和返回内容都是不可信输入**。恶意网页/邮件内容可能通过工具结果被"提示注入", 诱导模型调用危险工具 (如删除文件、转账)。写操作类工具应在代码里加确认环节, 而不是指望模型自觉;
- **最小权限**: 给工具的范围越窄越好。文件工具限定目录, 数据库工具用只读账号, 能只读就不要给写;
- **远程服务看清 issuer**: OAuth 授权时核对 `iss` 参数, 避免混流攻击; 企业内网部署配合网关做审计和限流。

## 小结

- MCP 把"AI 应用 × 工具"的 M×N 集成问题变成 M+N: Server 写一次, 处处可用;
- 三个角色 (Host / Client / Server)、两种传输 (stdio 本地 / Streamable HTTP 远程)、三类原语 (Tools / Resources / Prompts);
- 2026-07-28 起协议核心无状态化, 远程部署和普通 HTTP 服务一样可扩展、可缓存、可观测;
- 自己写 Server 的门槛极低: 装饰三个函数, 注册进客户端, AI 立刻多出一只手。

## 参考资料

- 官方规范与文档: [modelcontextprotocol.io](https://modelcontextprotocol.io/)
- 2026-07-28 修订说明: [A Stateless MCP](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/) (官方博客)
- Python SDK: [github.com/modelcontextprotocol/python-sdk](https://github.com/modelcontextprotocol/python-sdk) , 迁移指南 [py.sdk.modelcontextprotocol.io/v2/migration](https://py.sdk.modelcontextprotocol.io/v2/migration/)
- 官方服务注册表: [registry.modelcontextprotocol.io](https://registry.modelcontextprotocol.io/)
- 参考实现与示例 Servers: [github.com/modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers)
