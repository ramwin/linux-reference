# 测试智能体平台：Skill 管理与「千人千面」架构方案

```{contents}
```

本文给出一套可落地的完整设计，重点回答三个问题：**每个用户的 Skill 怎么管理**、**怎么做到千人千面**、**Skill 存储的详细方案**。

## 1. 先定义清楚「Skill」是什么

在测试智能体里，Skill 不要只理解成「一段提示词」，而是一个**可复用、可组合、可个性化、版本化**的测试能力单元。建议按性质分成四类：

| 类型 | 例子 | 个性化点 |
|---|---|---|
| **能力型**（工具/流程） | API 自动化、UI 自动化、压测、安全扫描、Mock 数据构造、日志归因 | 参数、断言策略、重试次数 |
| **知识型**（领域/规则） | 电商交易规则、金融风控、合规要求、行业断言规范 | 领域上下文、术语表 |
| **流程型**（工作流模板） | 冒烟、回归、缺陷归因、发布门禁 | 步骤裁剪、触发条件 |
| **表达型**（风格/模板） | 用例描述风格、缺陷报告模板、测试报告模板 | 语言、粒度、格式 |

一个 Skill 的完整形态应该是一个**目录/包**，而不是单文件：

```
skill-ecommerce-order/
├── SKILL.md           # 是什么、什么时候用、怎么触发
├── manifest.json      # 元数据、参数 schema、依赖、权限声明
├── prompt.md          # 主提示词（含占位符 {{param}}）
├── tools/             # 工具定义（OpenAPI / function schema）
├── workflows/         # 可选 DAG 流程定义
├── examples/          # few-shot 示例（输入→期望行为）
└── resources/         # 知识文件、术语表、规则库
```

## 2. 千人千面的核心：分层 Skill + 实例化

「千人千面」不要靠给每个人存一份独立 Skill（会爆炸、无法维护），而是靠 **三层作用域 + 继承覆盖 + 实例化**：

```
官方 Skill（平台发布，版本化，只读）
   │  继承
   ▼
团队 Skill（继承官方 + 团队定制，覆盖部分参数/流程）
   │  继承
   ▼
用户 Skill 实例（继承团队 + 个人定制，最终运行时形态）
```

**关键概念**：`Skill 模板（定义）` 和 `Skill 实例（个性化后的运行时对象）` 分离。

- **模板**：平台/团队维护，版本化、不可变。
- **实例**：每个用户一份，记录「基于哪个版本的模板 + 覆盖了哪些东西 + 偏好权重」。

这样 1000 个用户对同一个「接口测试 Skill」就有 1000 份实例，但底层共享同一个版本化模板，既千人千面又可治理、可升级。

## 3. Skill 存储详细方案

### 3.1 存储技术分工

| 数据 | 存储 | 理由 |
|---|---|---|
| 元数据、版本、实例关系、权限、使用统计 | **PostgreSQL** | 强一致、关系查询、事务 |
| Skill 内容主体（prompt/工具/examples） | **对象存储 S3/MinIO** + 内容寻址 | 大文本/文件，版本快照不可变 |
| 语义检索/匹配向量 | **pgvector 或 Milvus** | 用户画像 ↔ Skill 语义匹配 |
| 热 Skill、当前激活 Skill 集 | **Redis** | 运行时低延迟加载 |
| 使用埋点、反馈、画像更新 | **Kafka** | 异步回流、实时画像 |

### 3.2 核心表结构（PostgreSQL DDL）

**① Skill 模板（定义层，只存元数据）**

```sql
CREATE TABLE skill (
  skill_id        UUID PRIMARY KEY,
  code            VARCHAR(128) NOT NULL UNIQUE,   -- 唯一编码 e.g. api_rest_test
  name            VARCHAR(255) NOT NULL,
  category        VARCHAR(32),                    -- ability/knowledge/workflow/style
  scope           VARCHAR(16),                    -- official/team/private
  owner_type      VARCHAR(16),                    -- platform/team/user
  owner_id        VARCHAR(64),
  current_version INT NOT NULL DEFAULT 1,
  status          VARCHAR(16),                    -- draft/published/deprecated
  tags            TEXT[],
  capabilities    TEXT[],                         -- 能力点，用于匹配 e.g. ["rest","auth","json"]
  embedding       vector(1024),                   -- 模板语义向量
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);
```

**② Skill 版本（内容层，不可变快照）**

内容本体放对象存储，DB 只放指针 + manifest。版本不可变保证测试可复现。

```sql
CREATE TABLE skill_version (
  version_id    UUID PRIMARY KEY,
  skill_id      UUID NOT NULL REFERENCES skill(skill_id),
  version       INT  NOT NULL,
  content_ref   VARCHAR(255) NOT NULL,   -- S3 key 或 git commit，指向整个 skill 目录
  manifest      JSONB NOT NULL,          -- 参数 schema、依赖、触发条件、默认值
  prompt_hash   CHAR(64),                -- 内容寻址，用于去重/校验
  changelog     TEXT,
  created_by    VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (skill_id, version)
);
```

`manifest.json` 里最重要的是**参数 schema**，它是千人千面的「可配置面」：

```json
{
  "name": "api_rest_test",
  "version": 3,
  "parameters": {
    "base_url":        {"type": "string", "required": true},
    "auth_type":       {"type": "enum",  "values": ["none", "basic", "jwt", "oauth2"]},
    "assertion_strict": {"type": "enum", "values": ["strict", "loose"], "default": "loose"},
    "retry_times":     {"type": "int",   "default": 2, "min": 0, "max": 5},
    "timeout_ms":      {"type": "int",   "default": 5000}
  },
  "triggers": ["用户提到接口/API/HTTP 测试"],
  "dependencies": ["skill:http_client", "tool:report_gen"],
  "permissions": ["network.read", "file.tmp.write"]
}
```

**③ Skill 实例（个性化层，每用户一份）**

```sql
CREATE TABLE skill_instance (
  instance_id   UUID PRIMARY KEY,
  user_id       VARCHAR(64) NOT NULL,
  skill_id      UUID NOT NULL REFERENCES skill(skill_id),
  base_version  INT  NOT NULL,          -- 锁定基于哪个版本
  enabled       BOOLEAN NOT NULL DEFAULT true,
  config        JSONB NOT NULL DEFAULT '{}',  -- 用户对 manifest 参数的覆盖
  overrides     JSONB,                        -- prompt 片段注入、工具开关、流程裁剪
  weight        REAL NOT NULL DEFAULT 1.0,    -- 该 skill 对这位用户的权重
  pinned        BOOLEAN DEFAULT false,        -- 是否固定优先
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, skill_id)
);

-- 团队级也同构，只是 user_id → team_id，作为用户的继承父级
CREATE TABLE team_skill_instance (
  instance_id   UUID PRIMARY KEY,
  team_id       VARCHAR(64) NOT NULL,
  skill_id      UUID NOT NULL REFERENCES skill(skill_id),
  base_version  INT NOT NULL,
  config        JSONB NOT NULL DEFAULT '{}',
  overrides     JSONB,
  UNIQUE (team_id, skill_id)
);
```

**④ 用户画像（千人千面的输入）**

```sql
CREATE TABLE user_profile (
  user_id       VARCHAR(64) PRIMARY KEY,
  role          VARCHAR(64),           -- QA/开发/自动化工程师
  domains       TEXT[],                -- 电商/金融/游戏…
  tech_stack    TEXT[],
  preferences   JSONB,                 -- 报告语言、断言严格度、用例粒度等静态偏好
  embedding     vector(1024),          -- 画像向量（与 skill.embedding 同空间）
  updated_at    TIMESTAMPTZ DEFAULT now()
);
```

**⑤ 使用统计与反馈（千人千面「学习」的数据源）**

```sql
CREATE TABLE skill_usage (
  usage_id      BIGSERIAL PRIMARY KEY,
  user_id       VARCHAR(64) NOT NULL,
  skill_id      UUID NOT NULL,
  instance_id   UUID NOT NULL,
  task_type     VARCHAR(32),
  outcome       VARCHAR(16),           -- success/failed/partial
  feedback      SMALLINT,              -- 1~5 星或 -1/0/1
  exec_ms       INT,
  created_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_usage_user ON skill_usage(user_id, created_at DESC);
```

**⑥ 场景包（可选，把多个 Skill 组合成「测试套餐」）**

```sql
CREATE TABLE skill_bundle (
  bundle_id     UUID PRIMARY KEY,
  name          VARCHAR(255),
  scope         VARCHAR(16),
  owner_id      VARCHAR(64),
  skill_ids     UUID[],
  created_at    TIMESTAMPTZ DEFAULT now()
);
```

## 4. 千人千面：四层个性化机制

### 4.1 显式个性化（用户主动）

用户手动启用/禁用 Skill、改 `config` 参数、写 `overrides` 注入个人 prompt 片段、pin 常用 Skill。这是确定性最强的一层。

### 4.2 继承覆盖（自动合并）

运行时把三层配置做 **merge**（类似 CSS 级联 / OOP 继承）：

```
最终生效配置 = 官方默认 → 团队 override → 用户 override
```

合并规则要明确（JSON merge，数组可选择替换或追加），避免「用户改了团队又覆盖用户」的歧义。

### 4.3 上下文动态激活（Skill Router）

根据**当前任务上下文**动态选择/排序 Skill，而不是用户手动挑：

- 输入：用户画像向量 + 当前任务描述向量 + 被测系统元信息 + 最近使用记录。
- 过程：语义检索出候选 Skill → 按「相关性 × 历史成功率 × 用户权重 × 是否 pin」打分排序 → 取 Top-K 激活。
- 输出：本次会话的「激活 Skill 集」，注入 agent 的 system prompt 与工具集。

### 4.4 学习优化（反馈闭环）

`skill_usage` 的 outcome/feedback 通过 Kafka 回流，周期性（如每天）更新：

- 用户对某 Skill 的 `weight`（成功率高 → 上调，常失败 → 下调或降权）。
- 用户画像 `embedding`（行为漂移 → 画像更新）。
- 触发推荐（「你最近常做接口测试，要不要固定这几个 Skill？」）。

## 5. 整体架构

```{mermaid}
flowchart TB
  subgraph 用户侧
    U[用户 / Agent 会话]
  end

  subgraph 接入层
    API[API Gateway]
  end

  subgraph 核心服务
    ORCH[Skill 编排器 / Router]
    EXEC[Skill 执行引擎]
    PROFILE[用户画像服务]
    REC[推荐 / 匹配服务]
  end

  subgraph 数据层
    PG[(PostgreSQL<br/>元数据/实例/统计)]
    OSS[(S3/MinIO<br/>Skill 内容快照)]
    VEC[(pgvector/Milvus<br/>语义向量)]
    REDIS[(Redis<br/>热 Skill 缓存)]
    KAFKA[(Kafka<br/>埋点/反馈)]
  end

  U --> API --> ORCH
  ORCH --> PROFILE --> REC
  REC --> VEC
  ORCH --> REDIS
  ORCH --> EXEC
  EXEC --> PG
  EXEC --> OSS
  EXEC -->|使用/反馈埋点| KAFKA
  KAFKA --> PROFILE
  KAFKA --> REC
```

关键点：**运行时 Skill 加载走 Redis + OSS（快），画像与匹配走向量库（快），统计回流走 Kafka（异步，不阻塞执行）。**

## 6. 关键流程串起来

1. **发布 Skill**：上传目录 → 校验 manifest → 内容存 OSS（内容寻址）→ 写 `skill` + `skill_version` → 生成/更新 `skill.embedding`。
2. **实例化**：用户首次接触某 Skill 时，基于当前版本生成一条 `skill_instance`（config 为空 = 用默认），继承团队级实例。
3. **运行时**：会话开始 → Router 取用户画像 + 任务上下文 → 向量检索候选 → 打分排序 → 取激活 Skill 集 → 合并 config → 加载 prompt/工具 → 执行。
4. **反馈**：执行结果 + 用户评分 → 写 `skill_usage` → Kafka → 离线更新 weight/embedding。
5. **升级**：官方发布新版本时，用户实例仍锁定旧 `base_version`（**默认不强制升级，保证稳定**），通过「待升级」提醒让用户/团队决定是否跟进。

## 7. 权限与多租户隔离

- `scope + owner_id` 决定可见性：官方全可见、团队见团队内、私有仅本人。
- 用户实例只存「diff」，底层模板对用户**只读**，防止个人改动污染公共能力。
- 敏感参数（如账号、token）不进 skill 模板，放用户级 `secret` 存储，运行时注入，skill 只声明权限需求（manifest 里的 `permissions`）。

## 8. 治理与演进

- **版本锁定**：实例绑定 `base_version`，升级不破坏存量用户，可灰度。
- **复用度统计**：统计每个 skill 被多少实例引用、成功率分布，低价值 skill 下线。
- **Skill 市场**：官方/团队/个人三层可互相发布、fork、评分，形成生态。
- **可观测**：记录每次会话「激活了哪些 skill、merge 后的 config、最终 outcome」，便于归因与调优。

## 总结一句话

> **Skill 存成「版本化模板（不可变）+ 每用户实例（只存 diff）+ 画像向量」，运行时由 Router 做「语义匹配 × 继承合并 × 反馈权重」的动态激活，就是千人千面的落地方式。**
