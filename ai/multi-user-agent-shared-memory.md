# 多用户 Agent 系统: 部署在 K8s 上, 用户之间如何共享记忆与知识

```{contents}
```

## 先把问题拆开: "共享记忆"不是一件事

一个 Agent 系统里的"记忆"至少有四层, 共享范围各不一样, 混在一起设计必出问题:

| 层 | 内容 | 共享范围 | 例子 |
|---|------|---------|------|
| 会话记忆 | 当前对话的上下文 | 单次会话私有 | "上一轮你说过用 Postgres" |
| 用户记忆 | 这个用户的偏好、历史 | 用户私有, 跨会话 | "我喜欢简洁的回答" |
| 租户/团队记忆 | 团队沉淀的经验 | 租户内共享 | "我们团队的代码规范是..." |
| 全局知识 | 所有用户共用的知识库 | 全员共享 | 产品文档、FAQ、最佳实践 |

所以"用户之间共享记忆"在工程上真正的问题是: **怎么让多个用户的 Agent 实例读写同一批知识, 同时又不把彼此的私有数据泄露出去。** 在 K8s 上, 这个问题具体化为: 记忆存哪、Agent 实例怎么访问、怎么隔离、怎么保持一致性。

下面按常见方案展开, 最后给选型表。

## 方案总览

| 方案 | 记忆存哪 | Agent 怎么访问 | 适合场景 | 主要缺点 |
|------|---------|---------------|---------|---------|
| 一、共享文件卷 | RWX PVC (NFS/cephfs) 或对象存储 | 直接挂盘读文件 | 小团队、知识是文档文件 | 无语义检索, 无权限粒度 |
| 二、共享向量库 | 向量数据库独立部署 | SDK / HTTP 检索 | RAG 知识共享, 最主流 | 需要自己设计隔离模型 |
| 三、集中式记忆服务 | 自建 Memory Service (Postgres/Redis 后端) | REST/gRPC API | 结构化记忆 + 细粒度权限 | 要自研, 有维护成本 |
| 四、MCP 记忆服务器 | MCP Server 作为共享服务 | Agent 通过 MCP 协议调用 | 已用 MCP 生态的系统 | 协议偏工具调用, 大批量检索不经济 |
| 五、消息队列同步 | Kafka 等, 各实例本地存副本 | 事件发布/订阅 | 多实例最终一致的记忆广播 | 一致性复杂, 有延迟 |
| 六、知识图谱 | Neo4j 等图数据库 | Cypher 查询 | 实体关系型知识 | 建设与维护成本最高 |

实际系统几乎都是**组合使用**: 全局知识走向量库, 用户偏好走记忆服务, 热数据走 Redis, 互不矛盾。

## 方案一: 共享文件卷 —— 最简单直接

思路: 把知识文档放进一个 `ReadWriteMany` 的 PersistentVolume(NFS、cephfs、JuiceFS 都行), 所有 Agent Pod 挂载同一个卷; 或者直接放对象存储(MinIO/S3), 启动时同步。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-knowledge
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: cephfs
  resources:
    requests:
      storage: 20Gi
---
# Agent Pod 中:
volumeMounts:
  - name: knowledge
    mountPath: /knowledge        # 所有用户实例看到同一份文档
    readOnly: true               # 共享知识建议只读
```

要点:

- **共享知识挂只读, 写入走单独的发布流程**(一个 Job 或管理端写卷), 避免用户实例互相覆盖;
- 优点是零开发量, 缺点同样明显: 没有语义检索、没有权限粒度(要么全看到要么看不到)、大目录读取慢;
- 适合: 知识就是一批 Markdown/PDF 文档, 团队规模小, 先跑起来再说。

## 方案二: 共享向量库 —— 当前最主流

思路: 向量数据库(Qdrant / Milvus / Weaviate / pgvector)作为独立服务部署在集群里, 所有 Agent 实例通过网络访问, 用**集合(collection)划分 + 元数据过滤**实现"共享与隔离并存"。

K8s 上的典型部署:

```text
┌─────────────────────────────────────────────────────┐
│  namespace: ai-platform                             │
│                                                     │
│  agent-deployment (多副本, 服务多用户)               │
│      │                                              │
│      ▼ HTTP/gRPC                                    │
│  qdrant (StatefulSet + PVC)                         │
│    ├── collection: global_kb      ← 全员共享        │
│    ├── collection: tenant_a_kb    ← 租户 A 共享     │
│    └── collection: tenant_b_kb    ← 租户 B 共享     │
│                                                     │
│  embedding-service (Deployment)                     │
└─────────────────────────────────────────────────────┘
```

隔离的三种做法, 粒度从粗到细:

| 做法 | 实现 | 适用 |
|------|------|------|
| 按集合隔离 | 每个租户一个 collection, 全局知识单独一个 collection | 租户少而固定 |
| 按元数据过滤 | 单一大集合, 每条向量带 `tenant_id` / `visibility` 字段, 检索时强制加 filter | 租户多、动态创建 |
| 混合 | 全局知识一个集合 + 用户/租户记忆用元数据过滤 | **最常见** |

检索时把"该用户能看到的所有范围"拼进 filter:

```python
# 一次检索同时命中全局知识和本租户知识
results = vector_db.search(
    query_embedding=embed(question),
    filter={
        "should": [
            {"key": "scope", "match": "global"},
            {"key": "scope", "match": f"tenant:{tenant_id}"},
            {"key": "scope", "match": f"user:{user_id}"},
        ]
    },
    top_k=8,
)
```

要点:

- **写入路径要管起来**: 谁都能往全局知识写, 知识库很快就变成垃圾场。常见做法是用户写入先进"待审核区", 管理员或另一个审核 Agent 确认后才提升为全局可见;
- embedding 服务也部署在集群内, 避免每个 Agent Pod 各自加载模型浪费内存;
- pgvector 可以直接复用已有的 Postgres, 数据量不大(百万级向量以内)时比单独养一个 Milvus 省心得多。

## 方案三: 集中式记忆服务(Memory-as-a-Service)

思路: 把"记忆"做成一个独立的微服务, 提供 `remember` / `recall` / `forget` API, 后端用 Postgres(结构化记忆) + Redis(热数据、会话状态)。所有 Agent 实例无状态, 记忆全部收口到这一个服务, **权限、审计、TTL 都在这一层做**。

```text
┌────────────┐   ┌────────────┐   ┌────────────┐
│ Agent Pod  │   │ Agent Pod  │   │ Agent Pod  │   用户 A / B / C
└─────┬──────┘   └─────┬──────┘   └─────┬──────┘
      └────────────────┼────────────────┘
                       ▼ REST/gRPC
              ┌─────────────────┐
              │  memory-service │   ← 唯一写入口, 鉴权/审计/去重/合并
              │   (Deployment)  │
              └────────┬────────┘
            ┌──────────┼──────────┐
            ▼          ▼          ▼
         Postgres    Redis      Qdrant
       (事实/偏好) (会话热数据) (语义记忆)
```

API 形状大致是:

```text
POST /memories            {user_id, scope, content, ttl}
GET  /memories/recall     ?user_id=..&query=..&scopes=user,tenant,global
DELETE /memories/{id}     ← 支持"被遗忘权", 合规需要
```

相比"Agent 直连数据库"的优势:

1. **权限收口**: Agent Pod 拿不到数据库凭据, 只能带着用户身份调 API, 服务层校验 `scope`, 用户 A 永远读不到用户 B 的私有记忆;
2. **写入治理**: 去重(相似记忆合并)、冲突处理(新事实覆盖旧事实)、审计日志, 都有地方放;
3. **Agent 无状态化**: Agent Deployment 可以随意扩缩容、滚动更新, 记忆不丢。这是 K8s 上最舒服的一点 —— Pod 就是耗材, 状态全在外面。

开源世界里 Mem0、Zep 这类项目干的就是这件事, 可以直接部署在集群里当这个服务用, 也可以按它的思路自研。

## 方案四: MCP 共享记忆服务器

思路: 如果系统已经基于 MCP 搭工具生态(见 [MCP: AI 应用的"USB-C"接口](./mcp.md)), 那么"共享记忆"可以就是一个 MCP Server, 对外暴露 `search_knowledge` / `save_memory` 之类的工具。

在 K8s 上把它部署成集群内的常驻服务:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-mcp-server
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: server
          image: your-org/memory-mcp:latest
          env:
            - name: DATABASE_URL
              valueFrom: { secretKeyRef: { name: memory-db, key: url } }
```

各 Agent 以 streamable HTTP 方式连接这个 MCP Server。好处是**协议标准化**: 不同框架写的 Agent(LangChain 的、自研的)都能用同一份记忆, 换 Agent 框架不用改记忆层。代价是每次记忆读写都是一次工具调用, 高频大批量检索不如直接 SDK 连库经济 —— 所以它适合"低频、需要模型自己决定何时存取"的记忆, 不适合每轮对话都跑的热路径。

## 方案五: 消息队列同步 —— 多实例最终一致

思路: 每个 Agent 实例(或每个用户分片)持有本地记忆副本保证低延迟, 写入时发事件到 Kafka, 其他实例订阅后更新自己的副本:

```text
Agent-1 写入记忆 ──► Kafka topic: memory-events
                         ├──► Agent-2 消费, 更新本地缓存
                         ├──► Agent-3 消费, 更新本地缓存
                         └──► 归档消费者, 落 Postgres
```

适用面其实比较窄: 只有当你有**大量有状态实例**(比如每个用户一个常驻 Agent Pod, 用 StatefulSet 部署)且读延迟敏感时才值得。大多数情况下方案三(集中服务)更简单。如果用了, 必须处理好:

- 事件顺序(按 `user_id` 分区, 保证同一用户的记忆事件有序);
- 失败重放(消费者挂了, 重启后从 offset 继续);
- "刚写完立刻读"的读己之写一致性(写后同步查一次源, 或者写的时候同步更新本地)。

## 方案六: 知识图谱 —— 实体关系型共享知识

当共享知识不是"一堆文档段落"而是"实体和关系"("服务 X 依赖服务 Y"、"这个 bug 的负责人是张三")时, 向量检索力不从心, 用图数据库(Neo4j / NebulaGraph)作为共享记忆底座。各 Agent 查询时沿着关系遍历, 天然适合组织级的知识沉淀。

成本最高的方案: 实体抽取、关系维护、图谱清洗都是活。一般作为向量库的**补充**而不是替代 —— 向量库管"语义相似", 图谱管"精确关系"。

## K8s 部署形态的选择

不管选哪个方案, 都要回答"记忆组件以什么形态跑在集群里":

| 形态 | 做法 | 适合 |
|------|------|------|
| 独立服务 | 记忆服务/向量库做成独立 Deployment/StatefulSet + Service, Agent 通过 ClusterIP 访问 | **绝大多数情况**。无状态 Agent + 有状态记忆分离, 扩缩容互不干扰 |
| Sidecar | 每个 Agent Pod 里跑一个记忆容器 | 几乎不推荐用于"共享"场景: sidecar 天生是 per-Pod 的, 和共享矛盾; 只适合本地缓存层 |
| DaemonSet | 每个节点一个记忆代理 | 极端低延迟本地缓存, 配合方案五的副本同步 |
| Operator 管理 | 用 Operator 管理向量库/图数据库的生命周期(备份、扩缩容) | 生产环境, 有状态组件多的时候 |

两条经验:

1. **Agent 无状态, 记忆外置**。这是 K8s 上的金科玉律, 也是"能共享"的前提 —— 记忆在 Pod 里, Pod 一重启就没了, 更谈不上共享;
2. **有状态组件用 StatefulSet + PVC**, 并且备份策略从第一天就要有。记忆丢失比代码故障更难恢复。

## 共享的三个坑: 隔离、一致性、治理

### 隔离: 共享的反面是泄露

- 所有记忆条目必须带 `tenant_id` / `user_id` / `scope`, 检索侧**强制过滤**, 不能依赖调用方自觉传 filter —— 在记忆服务层默认追加当前身份的范围;
- 向量库层如果用 K8s NetworkPolicy 限制只有记忆服务能连向量库, 就堵死了"绕过 API 直连库"的口子;
- 删除权: 用户要求删除自己的记忆时要能删干净(向量库、关系库、备份里), 合规场景这是硬需求。

### 一致性: 两个人同时写入怎么办

- 用户 A 说"数据库密码是 X", 用户 B 说"是 Y", 全局知识里信谁? 常见做法: 写入带版本号和时间戳, 新覆盖旧但保留历史; 冲突条目标记为 `contested`, 召回时如实告诉模型"有两种说法";
- 写全局知识走审核流(方案二里说的待审核区), 是防止知识污染最有效的单一手段。

### 治理: 记忆会腐烂

- TTL: 会话记忆小时级, 用户偏好月级且每次命中自动续期, 全局知识定期人工/模型复审;
- 去重合并: 相似度极高的记忆合并, 否则召回结果全是重复内容挤占上下文;
- 可观测: 记录每条记忆的命中率, 长期零命中的就是该清理的; 记录谁在什么时候写了什么, 出问题能追溯。

## 选型建议

| 你的情况 | 建议 |
|---------|------|
| 先把功能跑起来, 团队 < 20 人 | 方案一(共享卷) + 方案二(pgvector 单集合), 一周能上线 |
| 标准 SaaS 多租户, 需要可靠隔离 | 方案三(记忆服务) + 方案二(向量库元数据过滤), Agent 无状态化 |
| 已重度使用 MCP 生态 | 在方案三外面包一层方案四的 MCP Server |
| 每用户一个常驻实例, 读延迟敏感 | 方案五(事件同步)叠加本地缓存 |
| 知识是强关系型(依赖、负责人、拓扑) | 方案二之上补方案六的图谱 |

一条通用结论: **共享走"集中式服务 + 范围标签", 私有走"强制过滤", 写入走"审核流", 这三句话覆盖了 90% 的多用户 Agent 记忆设计。**

## 参考资料

- [Mem0](https://github.com/mem0ai/mem0) —— 开源的 Agent 记忆层, 方案三的典型实现
- [Zep](https://github.com/getzep/zep) —— 另一条记忆服务路线, 时序知识图谱驱动
- [Qdrant Multitenancy](https://qdrant.tech/documentation/guides/multiple-partitions/) —— 向量库多租户隔离的官方做法
- [Model Context Protocol](https://modelcontextprotocol.io/) —— 方案四的协议基础

延伸阅读: [RAG: 检索增强生成](./rag.md)、[MCP: AI 应用的"USB-C"接口](./mcp.md)、[从学习到生产](./production-deployment.md)。
