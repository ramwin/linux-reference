# openJiuwen 分析:与多智能体测试平台的关系

## 一、是什么

openJiuwen(开源九问)是华为实验室、华为云、小艺终端团队联合开源的**生产级 AI Agent 平台**,
Apache 2.0 协议,2025 年底开源,2026 年 8 月在 828 B2B 企业节正式发布。

- GitHub: <https://github.com/openJiuwen-ai>,PyPI 包名 `openjiuwen`(Python 3.11-3.13)
- 定位类比 LangChain/LangGraph,但更偏**生产环境多 Agent 协同**:蜂群协作、断点续跑、
  状态持久化、低代码可视化编排、全链路调试追踪
- **本身不带模型权重**,兼容所有 OpenAI 兼容接口(Qwen、DeepSeek、GLM、Ollama 本地模型)
- 与华为云 AgentArts 企业版同源度 >90%,社区版可平滑升级企业版

## 二、模块组成

分层架构,覆盖 Agent 开发→运行→部署→运维全生命周期:

| 层 | 仓库 | 说明 |
|---|---|---|
| DeepAgents(应用层) | `jiuwenswarm` | 多 Agent 蜂群协同框架,旗舰应用,支持 Skill 自演进 |
| | `jiuwensymbiosis` | 具身智能 Agent 框架,构型无关的能力复用与安全控制 |
| | `deepsearch` | 知识增强型深度检索/研究 Agent,搜索+推理+报告生成 |
| SkillHub | `skillhub` | Skill 托管分发平台:发布、版本管理、检索下载、共享复用、私有化部署 |
| Agent Studio | `agent-studio` | 一站式可视化低代码开发平台:Agent 编辑、工作流编排、Prompt 调优、在线调试 |
| Agent Framework | `agent-core` / `agent-core-java` | 核心 SDK:编排、运行时、模型接入、工具、检索、评测 |
| | `agent-memory` | 长期记忆系统:记忆抽取、压缩、混合检索、沉淀构建、自主演化 |
| | `agent-gateway` | 统一接入网关(Channel 管理、消息、定时任务、心跳),尚未开放 |
| Agent Runtime | `agent-runtime` / `agent-runtime-java` | 分布式运行时:服务化执行、会话/生命周期管理、多租户隔离、弹性扩缩、跨集群互通 |
| | `agent-protocol` | 互操作协议 SDK:MCP、A2A、A2X Registry |
| Agent System Service | — | AgentOS 底层:安全沙箱、统一记忆持久化存储、原生 CLI、标准化 Agent 文件系统、跨 Agent 消息总线 |

周边生态:

- `JiuwenClaw`(小龙虾):类 OpenClaw 的个人 Agent 工具,邮储银行 PSBC-Claw、
  华为云 OfficeClaw 都是基于它定制的
- **Agentic Hub**(2026-09 发布):智能体资产平台,把能力拆成技能/连接器/插件/专家/专家团
  五类可复用资产,覆盖创建、安装、使用、发布、再获取的完整生命周期,号称"Agent 版 Hugging Face"
- **Team Skills / Swarm Skills**:把团队协作流程、任务范式、沟通策略、调度策略标准化封装成
  可复用的"团队级技能"(Coordination Engineering 范式),且支持 Skill 自主演进

## 三、和多智能体测试平台重叠吗

结论:**方向不同,重叠很小**。openJiuwen 是"供给端"(造 Agent、跑 Agent、管 Agent),
测试平台是"验收端"(度量 Agent 好不好、有没有回归)。

| 维度 | openJiuwen | 我们的测试平台 |
|---|---|---|
| 核心问题 | 怎么构建和运行 Agent | 怎么度量 Agent 能力边界、发现回归 |
| 多 Agent | JiuwenSwarm 蜂群协同(分工干活) | 多 Agent 协作的测试场景构造与评估 |
| 自演进 | Skill 自演进(越用越强) | 测试资产自进化(失败聚类、用例生成) |
| 评测 | `agent-core` 里有 evaluation 模块,SDK 附属能力 | 平台级 eval 体系,主战场 |
| 用户体系 | 多租户资源隔离(运维视角) | 多用户评分/偏好分桶(质量视角) |

它不做的事恰恰是测试平台的核心:失败聚类、评分聚合、回归测试、judge 校准、多用户评分体系。

## 四、复用策略

| 方案 | 做法 | 利 | 弊 |
|---|---|---|---|
| A. 作为被测对象 | 测试平台支持评测 openJiuwen 构建的 Agent(走 A2A/MCP 接入) | 零耦合;借华为生态势能 | 无代码级复用 |
| B. 复用独立组件(推荐) | 按需引入 `agent-protocol`、`agent-memory`、Swarm Skills 规范 | 模块松耦合、Apache 2.0、可单独 pip 安装 | 路线图受华为主导;部分仓(agent-gateway)未开放 |
| C. 基于它搭底座 | 用它的 Runtime + Studio 做底座,上面加测试层 | 最快出全套能力 | 平台级锁定,放弃技术主权,不建议 |

**建议以 B 为主、A 为辅**,优先级:

1. `agent-protocol`:测试平台要驱动各种 Agent 跑用例,MCP/A2A 协议层直接用它的 SDK,避免自研
2. Swarm Skills / Team Skills 规范:它把"团队级协作 SOP"标准化封装的思路,与测试平台里
   "多 Agent 协作场景用例"的建模同构,可借鉴甚至兼容其格式,让测试资产能在 Agentic Hub 生态流通
3. `agent-memory`:测试经验沉淀(记忆进化层)可参考或直接用它的记忆抽取/压缩/混合检索
4. 反向机会:openJiuwen 生态缺强 eval 能力,测试平台支持评测 JiuwenSwarm 团队是切入其生态的
   差异化卖点——华为系落地场景(如邮储银行)天然需要验收端

**方案 A 的现成评测资产:Finding the Right Fit**。论文
[Finding the Right Fit: Model-Harness Interactions across Agent Tasks](https://huggingface.co/papers/2610.00917)
把 openJiuwen、OpenHands、DeepSeek Harness(DSH)、PI 四个 harness × 5 个模型做了 66 组交叉评测,
结论是**模型 × harness × 任务要联合评测,排名会随配置反转**——例如 Terminal-Bench 上 Claude 在
OpenHands 领先 GPT 7.94 分,在 PI 里反而落后 30.16 分;openJiuwen 则让 Kimi 在三个 benchmark 都拿到最高分。
它开源了 harness 适配器 + 6,204 条打分轨迹
([数据集](https://huggingface.co/datasets/yixuanli97/finding-the-right-fit)),可直接作为测试平台方案 A
的评测基线与方法论起点:"选 harness 要看 模型×harness×任务 组合"正是验收端该提供的能力。

风险提示:与 AgentArts 企业版同源 >90%,商用前确认社区版/企业版功能边界,
避免"社区版够用→企业版收费"的路径依赖。

## 五、原始资料整理(供横向对比)

以下按来源整理搜索到的原始信息,保留细节以便后续与其他 Agent(平台)对比。

### 5.1 发展时间线

| 时间 | 事件 |
|---|---|
| 2025 年底 | openJiuwen 社区开源上线,采用 Studio / Core / Ops 分层架构 |
| 2026-03 | 开源基于 Python 的 `JiuwenClaw`(小龙虾),支持与华为云 MaaS 服务和小艺开放平台对接 |
| 2026-04-28 | 首发 **Coordination Engineering(协同工程)** 全栈技术体系,发布 `JiuwenClaw Team Skills`(业界首个面向多 Agent 协作的标准化能力包规范) |
| 2026-05-21 | 发布 `JiuwenSwarm` 与 **Swarm Skills Hub** |
| 2026-08-27 | 828 B2B 企业节上华为 openJiuwen 智能体平台正式发布(华为公司董事、华为云 CEO 周跃峰等出席) |
| 2026-09 | 发布首个开源智能体资产平台 **Agentic Hub**(<https://agentichub.openjiuwen.com/>) |

### 5.2 Coordination Engineering 与 Skills 体系

来源:中华网、博客园、比特网等 2026-04/05 报道。

- 行业叙事:Prompt Engineering → Context Engineering → Harness Engineering,单 Agent 能力增强后,
  行业转向多 Agent 协同;痛点是团队编排、任务调度、通信协议都要从零造轮子
- **Team Skills**:把智能体团队的协作流程、任务范式、沟通策略、执行规范沉淀为团队协作 SOP,
  使团队能力可沉淀、可复用
- **Swarm Skills**:把跑通的最佳实践、SOP、角色搭配、调度策略标准化封装成"团队级技能";
  Swarm 基于 Coordination Engineering 实现多智能体自主分工、动态协商、持续演进,全程无需人工干预
- **Skills 自主演进**:工具调用失败或需求理解错误时,系统主动记录、分析根因、生成改进建议,
  弹审批窗口由用户决定是否更新("双层优化")
- JiuwenClaw 已内置:开发编程、办公与生产力、内容创作、多模态与媒体、数据与科研、
  合规与法律、生活与健康、金融等场景 Skills

### 5.3 落地案例

- **邮储银行 PSBC-Claw**:基于 JiuwenClaw 深度定制,覆盖数据接入、知识更新、技能准入、
  模型运算到结果输出的全流程安全管控;用于内部情报监测、风险预警、技术洞察,
  7×24 全自动值守,分钟级情报获取、智能分析、多渠道实时推送
- **华为云 OfficeClaw**:聚焦 PPT 制作、邮件整理、纪要生成、文件处理、深度洞察等泛办公任务
- 制造、医疗、金融等行业与软通动力、北明软件等伙伴共建

### 5.4 Agentic Hub 五类资产模型

来源:机器之心 2026-09 报道。

- 问题定义:多数 Agent 产品把能力做成封闭内置功能,Prompt/MCP/工具/多 Agent 协作停留在
  当前会话和项目里,任务完成后难以沉淀为可复用资产
- 五类资源(不是五种互相替代的 Agent,而是围绕任务组合使用的资源单元):
  - **技能(Skill)**:沉淀方法
  - **连接器(Connector)**:接入外部系统
  - **插件(Plugin)**:组合能力
  - **专家(Expert)**:定义角色
  - **专家团(Expert Team)**:组织协作
- 生命周期:创建 → 安装 → 使用 → 发布 → 再次获取;本地验证后的能力可发布至 Agentic Hub 共享;
  承载于蜂群智能体 WorkSwarm 和 Agentic Hub 中

### 5.5 技术细节(51CTO 实测文)

- 安装:`pip install openjiuwen`,要求 Python 3.11-3.13
- `agent-core`:底层运行引擎,**ReAct Agent + Workflow 双模式**;异步流式、状态保存、任务中断恢复
- 两种使用方式:SDK 代码调用(`import openjiuwen`,类似 langchain);或 Docker 拉起全套平台
  用 Studio Web 界面拖拽编排(SDK 包本身不带 Web 界面)
- 模型接入:`LLMConfig(api_base=..., api_key=..., model=..., provider="openai_compatible")`,
  任意 OpenAI 兼容端点(Ollama、DashScope 兼容模式等)
- 工具调用:`@tool` 装饰器自动解析函数签名和 description 生成 function-call schema,无需手写 JSON schema;
  要求模型支持 function-call(qwen3-8b / qwen3.5 系列可用)
- JiuwenSwarm 用法:`JiuwenSwarm(llm_config=..., agents=[子Agent1, 子Agent2])`,子 Agent 可各配工具
- 适合场景:复杂任务多 Agent 分工、业务系统内嵌智能体、企业私有化部署、需要断点续跑/状态持久化;
  不适合:简单聊天问答(太重,LangChain 更轻)

与 LangChain 对比(该文观点):

| | openJiuwen | LangChain |
|---|---|---|
| 侧重点 | 生产级多 Agent 蜂群、状态持久、断点续跑 | 通用 LLM 应用组件库 |
| 可视化 | 自带 Studio 零代码 Web 界面 | 需自己搭 UI |
| 多 Agent | JiuwenSwarm 原生蜂群协同 | 靠 LangGraph 手动编写图逻辑 |
| 部署 | Docker 容器化整套平台 | 偏 SDK 库,部署自己实现 |
| 模型 | 兼容所有 OpenAI 格式 API | 兼容几乎全部大模型 |

### 5.6 与 Dify / Coze 选型对比(华为云社区文观点)

- openJiuwen 与 Dify 均 Apache 2.0 开源,可自托管、数据不出网、迁移成本低;Coze 是纯 SaaS,有锁定/涨价风险
- openJiuwen 独有优势:代码版权归属华为(公司背书,非社区野项目);与 AgentArts 企业版同源 >90%,
  小项目用社区版、大项目平滑升级企业版
- 该文同时提醒:开源不等于不被锁定,基于 openJiuwen Runtime 深度构建仍有平台绑定成本

### 5.7 待核实项

- `agent-core` 的 evaluation 模块具体能力边界(公开资料只提到"评测"二字,未深入)
- `agent-gateway` 仓库状态(官方标注 Opening Soon)
- 社区版与 AgentArts 企业版的具体功能差异和授权边界
- GitHub 各仓 star/活跃度/issue 响应速度(本次未采集)

### 5.8 Finding the Right Fit 论文(一手,arXiv:2610.00917)

来源:论文 arXiv 页 + 配套仓库 [liyix/finding-the-right-fit](https://github.com/liyix/finding-the-right-fit)
(已 clone 通读 README)。这篇是「把 harness 当被测对象」的现成工程,且**已带 openJiuwen 和 DSH 两个适配器**。

**评测设计**:66 配置 = 4 个可配置 harness × 5 模型 × 3 benchmark,外加原生 Codex-GPT、Claude Code-Claude 配对。

- 4 harness:OpenHands、DeepSeek Harness(DSH)、PI、openJiuwen
- 5 模型(OpenRouter 锁定 provider):Claude Opus 5、GPT-6 Astra、GLM-5.3、Kimi K3、DeepSeek V4 Pro
- 3 benchmark:TUA-Bench(120 通用终端任务)、ALE-CLI(99 专业工作流)、Terminal-Bench 4(63 硬核命令行任务)

**关键结论**(含具体数字,可直接引用):

- 模型排名随 harness 反转;Terminal-Bench 4 上 Claude 在 OpenHands 领先 GPT 7.94 分,在 PI 反而落后 30.16 分
- 4/5 模型的最优 harness 随 benchmark 变;但 openJiuwen 让 Kimi 三个 benchmark 都拿到最高分(+5.61~11.11)
- 厂商自家 harness 不一定是模型最优;更高成本不保证更高分
- Terminal-Bench 4 上 GPT 在 PI 下比 DSH 下分数更高,单任务成本不到 1/4
- 归因:模型几乎都自己发起修复,差别在于 harness 是否把失败以模型可用的形式交还;GPT 适合 PI 的 lean scaffold,
  Kimi(常发畸形 tool call)适合 openJiuwen

**完整结果表**(分数为 score%,成本为美元/任务,粗体为该模型该 benchmark 最优 harness):

TUA-Bench:

| 模型 | OpenHands | DSH | PI | openJiuwen | Native |
|---|---:|---:|---:|---:|---:|
| Claude Opus 5 | 65.2 / $0.72 | 58.8 / $0.76 | 58.2 / $0.59 | 65.4 / $1.35 | **68.9 / $0.95** |
| GPT-6 Astra | 61.0 / $0.72 | 64.3 / $1.26 | 65.4 / $0.64 | **66.3 / $1.31** | 63.7 / $0.94 |
| GLM-5.3 | 62.9 / $0.43 | 56.2 / $0.47 | 53.6 / $0.25 | **63.0 / $0.38** | – |
| Kimi K3 | 50.5 / $0.39 | 58.4 / $0.40 | 58.8 / $0.28 | **64.4 / $0.47** | – |
| DeepSeek V4 Pro | 56.5 / $0.12 | 51.9 / $0.11 | 57.6 / $0.10 | **62.6 / $0.36** | – |

ALE-CLI:

| 模型 | OpenHands | DSH | PI | openJiuwen | Native |
|---|---:|---:|---:|---:|---:|
| Claude Opus 5 | 53.1 / $5.03 | 43.5 / $3.56 | 50.2 / $3.27 | 51.3 / $4.89 | **54.3 / $5.76** |
| GPT-6 Astra | 53.9 / $2.78 | 49.0 / $6.79 | **58.5 / $2.70** | 56.7 / $5.19 | 56.3 / $4.87 |
| GLM-5.3 | **51.7 / $2.07** | 46.1 / $1.62 | 47.7 / $1.40 | 48.3 / $1.97 | – |
| Kimi K3 | 39.1 / $2.19 | 41.7 / $1.07 | 48.0 / $1.53 | **54.9 / $2.23** | – |
| DeepSeek V4 Pro | **51.2 / $0.50** | 40.9 / $0.42 | 47.7 / $0.26 | 50.8 / $0.68 | – |

Terminal-Bench 4:

| 模型 | OpenHands | DSH | PI | openJiuwen | Native |
|---|---:|---:|---:|---:|---:|
| Claude Opus 5 | **57.1 / $12.93** | 34.9 / $17.82 | 30.2 / $20.28 | 41.3 / $19.19 | 49.2 / $12.38 |
| GPT-6 Astra | 49.2 / $5.40 | 52.4 / $19.94 | **60.3 / $4.66** | 54.0 / $11.07 | 55.6 / $4.61 |
| GLM-5.3 | 41.3 / $7.39 | **42.9 / $6.53** | 31.7 / $5.98 | 41.3 / $11.38 | – |
| Kimi K3 | 11.1 / $8.75 | 17.5 / $7.85 | 11.1 / $7.73 | **28.6 / $11.92** | – |
| DeepSeek V4 Pro | 3.2 / $0.80 | **9.5 / $1.31** | 6.3 / $1.47 | 7.9 / $1.20 | – |

### 5.9 finding-the-right-fit 仓库结构(一手)

已 clone 通读。目录与工作流:

| 路径 | 内容 |
|---|---|
| `experiment.py` | CLI 入口:`setup` / `doctor` / `prepare` / `run` / `status` / `audit` |
| `experiment.yaml` | 论文配置:harness 版本锁定、每模型 OpenRouter 路由、reasoning/context/output/loop/timeouts/retries、成本对账、qualification 证据链 |
| `integrations/` | harness 适配器(Harbor agents + ALE deployers + OpenRouter 注入器) |
| `pilot/` | 各 campaign 启动脚本(含 openJiuwen 的 `pilot/*openjiuwen*`) |
| `release_tools/` | 各 harness 原生日志 → 统一轨迹格式的转换器 |
| `analysis/` | 结果表构建 + 论文图表复现脚本 |

**成本护栏**(付费跑分防跑飞,值得抄):`prepare` 生成不可变 manifest → `run` 必须回传 manifest 的 SHA-256 才启动 → `audit --fetch-provider` 与 OpenRouter per-generation 结算对账。原始 run 目录从不覆盖,重跑用新 run ID。

**harness 版本锁定表**(README):

| Harness | 版本 | 安装源 | TUA-Bench / Terminal-Bench 4 | ALE-CLI |
|---|---|---|---|---|
| OpenHands | 1.44.1 | pypi(`openhands-sdk`+`openhands-tools`) | Harbor 0.22.0 | ALE runner |
| DSH | 0.1.1-rc.2 | npm(`@deepseek-ai/dsh`) | Harbor 0.22.0 | ALE runner |
| PI | 0.84.4 | npm(`@earendil-works/pi-coding-agent`) | Harbor 0.22.0 | ALE runner |
| openJiuwen | 0.1.18 | pip(`openjiuwen`,用公开 harness API 组装) | Harbor 0.22.0 | ALE runner |
| Codex | 0.150.1 | npm(`@openai/codex`) | Harbor 0.22.0 | ALE runner |
| Claude Code | 2.1.251 | npm(`@anthropic-ai/claude-code`) | Harbor 0.22.0 | ALE runner |

**openJiuwen 的接入文件**(README 明示 openJiuwen 是 framework 不是 packaged agent,不占 `experiment.py` 的 harness ID):

- `integrations/harbor_openjiuwen.py`(Terminal-Bench)、`integrations/harbor_openjiuwen_tua.py`(TUA-Bench)
- `integrations/ale_agents/study_openjiuwen`(ALE-CLI)
- `integrations/openjiuwen_agent.py`(agent 组装,约 1300 行)

### 5.10 openJiuwen harness 组装要点(通读 openjiuwen_agent.py 提炼)

核心 API 与机制:

- `from openjiuwen.harness import create_deep_agent` + `openjiuwen.core.runner.Runner`(`start`/`run_agent`/`stop`) + `openjiuwen.core.session.agent.Session`
- **Rail 机制**(`openjiuwen.harness.rails.base.DeepAgentRail`):用 Rails 列表组装行为,组装用到
  `SysOperationRail`、`ContextProcessorRail`、`TaskCompletionRail`、`ModelAnomalyDetectionRail` 等
- `ModelClientConfig`(ProviderType.OpenRouter)+ `ModelRequestConfig` 配模型,`extra_body` 传 provider 路由与 reasoning effort

论文作者踩过的坑(组装 benchmark agent 时的兼容性 patch,可作为"framework 型被测对象"的接入难度参考):

- OpenRouter 推理回放:structured reasoning 只能经 `reasoning_details` 回放,plaintext 只能经 `reasoning_content`,二者不能同发
- OpenRouter 流式 idle 超时标记需并入 openJiuwen 原生超时分类器,否则无法重试
- 长 reasoning 的 SSE 累积存在 O(n²) 问题,需持久化链表优化
- 完成判定用 promise + `required_confirmations=2` 的自定义 Rail 驱动多轮

### 5.11 轨迹数据集(一手)

[Hugging Face 数据集](https://huggingface.co/datasets/yixuanli97/finding-the-right-fit):6204 条打分轨迹 = 66 配置 × 各自任务集,统一 chat 格式,每条含完整 model–tool 对话、reward、cost、token 用量、agent 耗时。

- 用途:分析 agent 行为、对比 harness、评测研究
- **红线:禁止用于训练/微调/蒸馏模型**(benchmark 本身同样要求)
- 代码 Apache 2.0;数据集另有条款,以数据集 card 为准

## 参考

- [GitHub: openJiuwen-ai](https://github.com/openJiuwen-ai)
- [arXiv: openJiuwen: Beyond Static Harnesses for Long-Horizon Coding Agents](https://arxiv.org/abs/2608.27969)
- [Finding the Right Fit: Model-Harness Interactions across Agent Tasks](https://huggingface.co/papers/2610.00917)([arXiv](https://arxiv.org/abs/2610.00917) / [代码仓库](https://github.com/liyix/finding-the-right-fit) / [6204 条轨迹数据集](https://huggingface.co/datasets/yixuanli97/finding-the-right-fit))
- [openJiuwen 上手指南(昇腾社区)](https://www.hiascend.com/developer/techArticles/20260325-1)
- [解密国产开源 AI-Agent 平台 openJiuwen(51CTO)](https://blog.51cto.com/u_16213723/14945819)
- [Agent 版 Hugging Face:openJiuwen 发布开源智能体资产平台(机器之心)](https://news.qq.com/rain/a/20260922A07K3400)
- [JiuwenSwarm 与 Swarm Skills Hub 发布(比特网)](https://telecom.chinabyte.com/491/352991.shtml)
- [国产 Agent 平台选型:openJiuwen、Dify、Coze(华为云社区)](https://bbs.huaweicloud.com/blogs/482023)
