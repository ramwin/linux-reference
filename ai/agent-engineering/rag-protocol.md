# RAG 服务有标准协议吗 —— 跨系统对接的现状与落地选择

```{contents}
```

前面 [RAG](../fundamentals/rag.md) 讲了"检索增强生成"的原理，[MCP](../fundamentals/mcp.md) 讲了工具接入的标准化。这篇回答一个工程上更现实的问题：**RAG 作为一个独立服务，对外有没有像 OpenAI Chat Completions 那样的标准接口？不同厂商、不同系统的 RAG 服务之间能不能即插即用？**

## 先说结论

**没有。** 截至 2026 年初，不存在一个被普遍采纳的"RAG 标准协议"。原因是 RAG 不是单一环节，而是一条管道：embedding → 向量检索 → rerank → 拼 prompt → 生成。每一层的标准化程度完全不同：

| 管道环节 | 标准化程度 | 事实标准 |
|---|---|---|
| 生成（LLM 调用） | ★★★★★ 高度统一 | OpenAI Chat Completions / Responses API，vLLM、Ollama、DeepSeek 等全部兼容 |
| Embedding | ★★★★☆ 基本统一 | OpenAI `/v1/embeddings` 请求/响应格式，主流模型服务都兼容 |
| 向量检索 | ★★☆☆☆ 各自为政 | Pinecone、Milvus、Qdrant、Weaviate、pgvector 各一套 API，互不兼容 |
| Rerank | ★★☆☆☆ 各自为政 | Cohere/Jina/TEI 格式相近但不通用 |
| 整包 RAG（query 进 answer 出） | ★☆☆☆☆ 完全私有 | OpenAI Retrieval API（vector stores）、Azure AI Search、阿里百炼、火山方舟……每家一套 |

## 正在收敛的三个"候选标准"

### 1. MCP：把检索当工具暴露（势头最猛）

[MCP](../fundamentals/mcp.md) 本来是为"AI 应用接工具"设计的，但 RAG 天然可以建模成一个 MCP server：暴露 `search(query, top_k)` 之类的工具，任何支持 MCP 的客户端（Claude、ChatGPT、Cursor、自己的 Agent）都能直接调。2025 年 OpenAI、Google 相继宣布支持 MCP 之后，它已经成为"检索服务对外暴露"最有希望的事实标准——相当于把 RAG 从"一个服务"降级为"一个工具"，绕开了管道内部怎么实现的争论。例如 Higress 的 RAG MCP Server 就是把整条 RAG 管道包成一个 MCP 服务对外。

### 2. OpenAI Retrieval API 格式：厂商私有但有影响力

OpenAI 自己的 [Retrieval API](https://developers.openai.com/api/docs/guides/retrieval)（vector stores + `file_search`）是"整包 RAG"里影响最大的一套接口设计：创建 vector store → 上传文件 → `POST /v1/vector_stores/{id}/search` 拿 chunk。部分厂商在跟进兼容这个格式，但它本质上是 OpenAI 私有 API，且只覆盖"语义搜索"这一段，不约定 rerank、混合检索、引用回传格式。

### 3. 上层协议：A2A 与框架抽象

Google 的 A2A（Agent2Agent）等协议管的是"Agent 和 Agent 之间怎么对话"，RAG 服务可以包成一个 Agent 参与，但这已经比"检索接口"高了两层。LangChain 的 Retriever 接口、LlamaIndex 的 QueryEngine 则是**代码库级别**的抽象——同一进程内换实现很方便，但不是网络协议，帮不了跨系统对接。

## 对接方案：四档对比

如果你要让自己的系统对接别人的 RAG 服务（或把自己的 RAG 服务给别人用），从简单到复杂有四档：

| 档位 | 做法 | 优点 | 缺点 | 适用 |
|---|---|---|---|---|
| L0 自定义极简 REST | `POST /search {query, top_k, filters}` → `{chunks: [{id, text, score, metadata}]}` | 半天落地，任何语言能调 | 只在自己体系内通用，换一家要重写适配层 | 内部系统、POC |
| L1 OpenAI 兼容套壳 | 整包 RAG 伪装成 `POST /v1/chat/completions`，引用放在扩展字段（如 `citations`） | 现有所有 OpenAI SDK/网关/监控直接可用；调用方无感 | 只能表达"整包 RAG"，拿不回原始 chunk；扩展字段仍是私有的 | RAG-as-a-Service，对外只给答案不给检索细节 |
| L2 MCP server | 检索能力按 MCP 协议暴露成工具 | 最贴近正在形成的事实标准；Claude/ChatGPT/Cursor 等客户端零代码接入 | 需要客户端支持 MCP；非 MCP 的传统后端调用方要多架一层 | 面向 AI 应用/Agent 生态开放检索能力 |
| L3 分层解耦 | embedding 用 OpenAI 兼容格式，向量存储用 pgvector（SQL 即接口），rerank 独立服务，自己拼管道 | 每层都可替换，不被任何一家绑死 | 管道自己维护，没有"整包"服务可买 | 长期核心系统、对可控性要求高 |

## 明确建议

- **对外提供 RAG 服务**：L1 + L2 双轨——一个 OpenAI 兼容的 chat/completions 端点（给传统调用方），一个 MCP server（给 AI 应用生态）。两者底下共用同一条检索管道。
- **对接别人的 RAG 服务**：优先问对方有没有 OpenAI 兼容端点或 MCP server；都没有就接受现实，写一个薄的适配层把对方的私有响应归一化成自己内部的 chunk 格式（`{id, text, score, metadata}` 四个字段足够）。
- **自建长期系统**：走 L3，embedding 接口强制 OpenAI 兼容——这是整条管道里唯一真正标准化了的部分，把它钉死，未来换模型/换厂商的成本最低。
- 对多 Agent 测试平台这类要做**多模型、多检索后端对比评测**的场景，内部先定义一个 L0 的最小 chunk 契约（四字段），外面不管接 Pinecone、pgvector 还是 MCP server，都收敛到这个契约上，评测代码只面向契约写一次。

## 参考

- [OpenAI Retrieval API 文档](https://developers.openai.com/api/docs/guides/retrieval)
- [MCP: AI 应用的 "USB-C" 接口](../fundamentals/mcp.md)
- [RAG: 检索增强生成](../fundamentals/rag.md)

## 版本记录

- v1（2026-02-14）：初稿成文。使用模型：k3-256k（DeepSeek Harness）。本次会话 token 统计（截至定稿）：input 26,113 + cache read 173,568 / output 4,916，合计约 20.5 万 tokens。
