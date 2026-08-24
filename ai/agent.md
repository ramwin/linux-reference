# 从0开始搭建一个 Agent

```{contents}
```

上一篇 [从0开始搭建本地 AI 服务](./local-ai-service.md) 搭出来的服务只会"说话"——你问一句,它答一句,仅此而已。这一篇给它装上"手":让模型能执行命令、查询数据、调用外部 API,并能根据执行结果继续决策,直到完成一个多步骤任务。这个东西就是 **Agent**。

学完之后你会拥有:一个跑在本地模型上、能自己查系统状态、执行命令的 Agent,并且知道它每一行逻辑在做什么。

```{toctree}
:maxdepth: 2
```

## Agent 与聊天机器人的区别

| | 聊天机器人 | Agent |
|---|---|---|
| 输入 | 一段话 | 一个任务 |
| 输出 | 一段话 | 一系列动作 + 最终结果 |
| 能力 | 只会"说" | 会"做":调用工具、观察结果、继续决策 |

Agent 的定义可以压缩成一句话:

```
Agent = LLM(大脑) + 工具(手) + 循环(神经系统)
```

```
+------------------------------------------------------+
|                    Agent 循环                          |
|                                                      |
|   +----------+  tool_call(我要执行这个)  +----------+ |
|   |          | ------------------------> |   工具    | |
|   |   LLM    |                           | (shell/  | |
|   |  (决策)  | <------------------------ |  API/...) | |
|   |          |  tool result(执行结果)     +----------+ |
|   +----------+                                       |
|        |                                              |
|        | 最终答案(不再调用工具)                         |
+--------v----------------------------------------------+
```

三个角色各司其职:

- **LLM 只负责决策**:读对话历史,决定"下一步做什么"——是提议调用某个工具,还是直接给出最终答案;
- **工具负责执行**:真正去操作系统、网络、数据库的那部分代码;
- **循环负责衔接**:把工具的执行结果作为新消息塞回对话,让 LLM 基于结果继续决策。

## 原理一:模型是怎么"调用工具"的

一个反直觉但必须建立的认识:**模型不会执行任何东西**。它从头到尾只做一件事——输出 token。所谓"调用工具",是模型输出一段格式特殊的文本(tool call),**由你的代码**去执行,然后把执行结果作为一条新消息塞回对话。模型只是"提出"要调用什么,真正动手的是外面那个循环。

### 协议:OpenAI 兼容的 Tool Calling

业界已经把这个过程标准化了(OpenAI 的 function calling 协议,本地引擎如 llama.cpp、Ollama、vLLM 都实现了它),整个交互分三步:

```{mermaid}
sequenceDiagram
    participant C as 你的代码
    participant M as 本地推理服务

    C->>M: 第1步: messages + tools 定义
    M->>C: assistant 消息, 带 tool_calls 而不是普通文本
    C->>C: 第2步: 执行工具, 得到结果
    C->>M: 第3步: 历史 + tool 结果消息, 再发一次
    M->>C: 最终答案, 或再次返回 tool_calls 回到第2步
```

> 图示:一次对话可能来回多轮。每一轮模型要么给出最终答案,要么给出要调用的工具——后一种情况循环继续。

### 工具怎么定义

你发给服务端的请求里,除了 messages,还要带上 `tools` 数组,用 JSON Schema 描述每个工具:

```json
{
  "type": "function",
  "function": {
    "name": "run_shell",
    "description": "在服务器上执行一条 shell 命令, 返回 stdout 和 stderr",
    "parameters": {
      "type": "object",
      "properties": {
        "command": {
          "type": "string",
          "description": "要执行的 shell 命令"
        }
      },
      "required": ["command"]
    }
  }
}
```

这段 JSON 就是工具给模型看的"说明书":模型读到它,就知道"存在一个叫 run_shell 的工具,参数是 command,我可以提议调用它"。

### 模型的 tool_calls 长什么样

模型看完说明书,如果决定调用工具,返回的消息里就带 `tool_calls`:

```json
{
  "role": "assistant",
  "content": null,
  "tool_calls": [{
    "id": "call_9f3a2b",
    "type": "function",
    "function": {
      "name": "run_shell",
      "arguments": "{\"command\": \"free -h\"}"
    }
  }]
}
```

两个容易踩坑的细节:

1. `arguments` 是 **JSON 字符串**,不是对象——代码里要先 `json.loads()` 再取字段;
2. 每个 tool_call 有一个唯一的 `id`,回传结果时要原样带回去(见下)。

### 执行结果怎么回传

你执行完工具,把结果包装成 `role: "tool"` 的消息追加到对话里:

```json
{
  "role": "tool",
  "tool_call_id": "call_9f3a2b",
  "content": "              total        used        free ...\nMem:           31Gi       3.1Gi        25Gi ..."
}
```

服务端收到后,模型就能"看到"执行结果,基于它继续生成——可能是再提议调用一个工具,也可能是给出最终答案。

## 原理二:为什么要循环(ReAct)

单个任务往往需要多步才能完成。比如"系统内存不够了,帮我找原因":

1. 查看内存使用情况(调 run_shell 执行 `free -h`);
2. 发现某个进程占用异常,查它的详情(再调 run_shell 执行 `ps aux | grep xxx`);
3. 得出结论,给出最终答案。

一次调用只能提议一个动作,所以 Agent 的骨架必然是一个循环。这种"推理-行动-观察"的模式就是 2022 年提出的 **ReAct**(Reason + Act):

```{mermaid}
flowchart TB
    A[用户任务] --> B[LLM 决策]
    B --> C{下一步?}
    C -- 调用工具 --> D[执行工具]
    D --> E[结果追加进对话]
    E --> B
    C -- 给出最终答案 --> F[返回用户]
    B -. 轮数超过上限 .-> G[强制终止]
```

> 图示:循环的出口有两个——模型给出最终答案(正常出口),或者轮数超过上限(兜底出口,防止死循环烧钱)。

## 动手:30 行代码写一个 Agent

依赖只有一个 openai 的 Python SDK——它把上面三步协议封装好了,而且 `base_url` 指向哪里,就和哪套 OpenAI 兼容接口对话(上一篇的 llama.cpp / Ollama 都可以):

```bash
pip install openai
```

完整代码:

```python
import json
import subprocess

from openai import OpenAI

# 指向上一篇文章搭好的本地服务(llama.cpp / Ollama / vLLM 均可)
# 注意 model 名要和服务的标签一致:llama.cpp 随意, Ollama 要写 "qwen2.5:7b"
client = OpenAI(base_url="http://localhost:8000/v1", api_key="local")

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "run_shell",
            "description": "在服务器上执行一条 shell 命令, 返回 stdout 和 stderr",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "要执行的 shell 命令"},
                },
                "required": ["command"],
            },
        },
    },
]


def execute_tool(name, arguments):
    """工具的实际实现, 与 TOOLS 里的定义一一对应"""
    if name == "run_shell":
        result = subprocess.run(
            arguments["command"],
            shell=True,
            capture_output=True,
            text=True,
            timeout=30,  # 超时强制终止, 防止命令挂死
        )
        return result.stdout + result.stderr
    raise ValueError(f"未知工具: {name}")


def run_agent(user_input, max_rounds=10):
    # 对话历史就是 Agent 的全部记忆
    messages = [{"role": "user", "content": user_input}]

    for _ in range(max_rounds):
        response = client.chat.completions.create(
            model="qwen2.5-7b-instruct",
            messages=messages,
            tools=TOOLS,
        )
        message = response.choices[0].message

        if not message.tool_calls:
            # 没有 tool_calls, 说明这是最终答案
            return message.content

        # 把 assistant 消息(含 tool_calls)原样放回历史
        messages.append(message.model_dump())

        # 逐个执行, 结果以 role="tool" 回传
        for call in message.tool_calls:
            args = json.loads(call.function.arguments)
            result = execute_tool(call.function.name, args)
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": result,
                }
            )
            print(f"[tool] {call.function.name}({call.function.arguments})")
            print(f"[result] {result[:200]}")

    return "达到最大轮数, Agent 未给出最终答案"


if __name__ == "__main__":
    answer = run_agent("查看系统内存使用情况, 如果剩余内存小于 1GB 就提醒我")
    print("=" * 40)
    print(answer)
```

运行:

```bash
python agent.py
```

一次典型的输出:

```
[tool] run_shell({"command": "free -h"})
[result]               total        used        free      shared  buff/cache   available
Mem:            31Gi       3.1Gi        25Gi       118Mi       2.7Gi        27Gi
Swap:          2.0Gi          0B       2.0Gi
========================================
系统当前剩余内存约 27GB, 远大于 1GB, 无需提醒。
```

### 逐段拆解

整个程序只有三个关键点:

1. **`messages` 就是 Agent 的全部记忆**。每一轮都把所有历史完整发回服务端——模型没有别的记忆,你删掉历史,它就"忘"了;
2. **含 tool_calls 的 assistant 消息必须原样放回历史**(`message.model_dump()`)。漏掉它,模型不知道"自己刚才提过什么";
3. **tool 消息必须带 `tool_call_id`**,与服务端要求的调用一一对应。填错或填漏,模型会把结果张冠李戴。

### 加第二个工具:扩展就是这么简单

加一个计算器工具,验证"工具即函数"的扩展性:

```python
TOOLS.append({
    "type": "function",
    "function": {
        "name": "calculate",
        "description": "计算数学表达式, 如 '2*3+4'",
        "parameters": {
            "type": "object",
            "properties": {
                "expression": {"type": "string", "description": "数学表达式"},
            },
            "required": ["expression"],
        },
    },
})


def execute_tool(name, arguments):
    if name == "run_shell":
        ...
    if name == "calculate":
        # 教学示例用 eval, 真实环境换成更安全的表达式解析器
        return str(eval(arguments["expression"]))
    raise ValueError(f"未知工具: {name}")
```

工具的定义(JSON)和实现(Python 函数)一一对应,增加工具 = 各加一段,循环代码一行不用改。这也是为什么业界要把工具标准化成 MCP 协议(见下文)——让工具的增删与 Agent 代码解耦。

## 设计工具的要点

工具是 Agent 的"手",但模型只见过你的 JSON 描述,没见过你的代码。工具设计直接决定 Agent 用得好不好:

- **description 是说明书**:写清楚"这个工具干什么、什么时候该用它"。描述含糊,模型要么不用,要么乱用;
- **参数少而明确**:参数越多,模型填错概率越大。能合并的参数就合并;
- **返回值短小结构化**:工具输出会被塞回对话上下文。甩给模型 1 万行日志,既挤爆 context,又稀释注意力。宁可工具内部先过滤、截断,只给结论;
- **结果要"对模型友好"**:带单位、带错误信息、明确成功/失败。模型看到 `exit code 1` 才知道该换条路,而不是继续硬编。

## 危险工具:shell 权限 = 多大权限

`run_shell` 是教学里最直观、生产里最危险的工具。给它的权限有多大,取决于你怎么理解这句话:

```{warning}
给 Agent 的 shell 权限,等于把 shell 权限交给"任何一个能给它发消息的人"。**提示词注入**(prompt injection)攻击的原理是:攻击者把指令伪装成网页内容、邮件正文、文件名,让模型误以为是任务的一部分。模型无法区分"用户说的"和"外部数据里夹带的",于是可能执行攻击者想要的命令。
```

生产环境收口权限的常规做法:

- **沙箱**:工具跑在 docker/firejail 里,文件系统和网络隔离;
- **白名单**:只允许执行预定义的命令清单,参数校验;
- **超时**:每条命令强制 timeout(示例代码里的 `timeout=30`);
- **人审**:高危操作(删除、外发数据)执行前人工确认。

学习阶段可以放开玩,但养成"每个工具都问一句:最小权限是什么"的习惯,后面会省很多事。

## Agent 常见失败与排查

| 症状 | 可能原因 | 处理 |
|------|---------|------|
| 模型完全不返回 tool_calls | 模型未训练过 function calling,或 description 太含糊 | 换支持工具调用的 Instruct 模型;重写工具描述 |
| 反复调用同一个工具不收敛 | 工具结果每次一样,模型以为没执行成功 | 让工具返回更明确的"已成功/已失败"信号;限制轮数 |
| `arguments` 解析失败 | 小模型输出 JSON 不稳定 | 换 7B+ 模型;在 description 里给参数示例(模型会模仿) |
| 多轮后回答质量下降 | 上下文塞了太多工具输出 | 截断/摘要工具结果,或换用更大的 context |
| 编造工具结果 | 工具失败但模型幻觉"完成了" | 让工具在失败时返回显式错误,模型更可能如实转述 |

## 进阶:MCP 与多 Agent

### MCP:统一工具协议

每换一个 Agent 框架(Claude Code、LangChain、自研循环),工具都要按它的格式重写一遍。**MCP**(Model Context Protocol)解决的就是这个问题:把工具定义成统一协议,工具方只写一次,任何支持 MCP 的 Agent 都能直接用。

```
+----------+   MCP(JSON-RPC over stdio/HTTP)   +-----------+
| MCP Host | <-------------------------------> | MCP Server |
| (Agent)  |  list_tools / call_tool / ...    | (工具提供方) |
+----------+                                    +-----------+
```

MCP 把工具、资源、提示词三类能力标准化,主流 Agent 框架都已支持。对学习而言,先把手写循环跑通,再接触 MCP 会更有体感——协议解决的是"规模化复用",而它背后的原理和上面的三步协议完全一致。

### 多 Agent

单 Agent 的上下文有上限,复杂任务可以拆给多个 Agent:一个编排者(orchestrator)拆解任务、分派,多个工作者(worker)各自带少量工具执行。多 Agent 本质上还是"LLM + 工具 + 循环"的组合,只是把循环又套了一层,本篇不展开。

## 下一步

Agent 跑通了,但它是"单用户、无鉴权、手动启动"的学习形态。下一篇 [从学习到生产](./production-deployment.md) 回答:把这个服务正式部署出去,交给很多人用时,应该怎么做。
