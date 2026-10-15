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

## 参考

- [GitHub: openJiuwen-ai](https://github.com/openJiuwen-ai)
- [arXiv: openJiuwen: Beyond Static Harnesses for Long-Horizon Coding Agents](https://arxiv.org/abs/2608.27969)
- [Finding the Right Fit: Model-Harness Interactions across Agent Tasks](https://huggingface.co/papers/2610.00917)
- [openJiuwen 上手指南(昇腾社区)](https://www.hiascend.com/developer/techArticles/20260325-1)
- [解密国产开源 AI-Agent 平台 openJiuwen(51CTO)](https://blog.51cto.com/u_16213723/14945819)
- [Agent 版 Hugging Face:openJiuwen 发布开源智能体资产平台(机器之心)](https://news.qq.com/rain/a/20260922A07K3400)
- [JiuwenSwarm 与 Swarm Skills Hub 发布(比特网)](https://telecom.chinabyte.com/491/352991.shtml)
- [国产 Agent 平台选型:openJiuwen、Dify、Coze(华为云社区)](https://bbs.huaweicloud.com/blogs/482023)
