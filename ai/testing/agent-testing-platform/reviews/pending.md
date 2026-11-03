# 待外部校对的断言清单

```{contents}
```

状态约定:`待校对`(还没问外部)/ `已校对`(有记录,见 reviews/)/ `已废弃`(被一手来源推翻)。

## 一、清单

| # | 断言(摘要) | 出处 | 为什么存疑 | 怎么校验 | 状态 |
|---|---|---|---|---|---|
| 1 | openJiuwen `agent-gateway` 仓库未开放(Coming Soon) | [landscape-openjiuwen.md](../landscape-openjiuwen.md) | 官方页面可能已更新 | 查 GitHub org 现有仓库 | 待校对 |
| 2 | openJiuwen 社区版与 AgentArts 企业版同源 >90%、商用边界不清 | 同上 | 数字来源是社区文章的推断 | 官方文档 / 授权页 | 待校对 |
| 3 | `agent-core` 的 evaluation 模块能力边界未知(公开资料只有"评测"二字) | 同上 | 未曾通读源码 | 读仓库源码与 README | 待校对 |
| 4 | Finding the Right Fit:4 harness × 5 模型 = 66 组交叉评测,排名随配置反转 | 同上 | 数字与结论需一手核对 | 论文原文 + 数据集 | 待校对 |
| 5 | "Claude 在 Terminal-Bench 上 OpenHands 领先 GPT 7.94 分、PI 里落后 30.16 分" | 同上 | 二手转述,可能记错方向 | 论文表格 | 待校对 |
| 6 | 自进化四层(记忆/工具/工作流/权重)的分类映射自 arXiv 2507.21046 的 What-When-How 框架 | [self-evolution.md](../self-evolution.md) | 原论文是综述,映射是我们的二次加工 | 论文原文 | 待校对 |
| 7 | 方案三(平台级)的启动阈值「消费方 ≥3」 | [architecture.md](../architecture.md) 第四节 | 纯经验判断,无一手依据 | 找行业案例 / 让外部模型给反例 | 待校对 |
| 8 | golden 集四项指标的具体阈值(契约合规率、diff 率、拦截率)未定 | [README.md](../README.md) 第五节 | 阈值依赖团队与任务类型 | 先跑基线再定;问外部模型同类实践的数值 | 待校对 |
| 9 | Redis 案例里的命令与参数符合 7.0 实际(ACL、RESP3、升级窗口写入语义) | [case-redis-upgrade.md](../case-redis-upgrade.md) | 案例是推演出来的,未全量实跑 | 对照 7.0 release notes 与实测 | 待校对 |
| 10 | Skill 千人千面的存储方案(PostgreSQL 元数据 + OSS 快照 + pgvector + Redis 热层)是当下主流 | [skill-personalization.md](../skill-personalization.md) | 选型未做横向对比 | 问外部模型同类系统的选型 | 待校对 |
| 11 | 多用户评分的聚合权重(客观正确性可共享、主观偏好分桶)没有定量方案 | [self-evolution.md](../self-evolution.md) 第二节 | 只有定性描述 | 找评分聚合的现成做法(如 Bradley-Terry / Elo 分桶) | 待校对 |
| 12 | JSONL 流式输出在长文本下的 schema 兜底成功率足够(配合 partial-json-repair) | [qa/0003](../qa/0003-等待大模型输出时能做什么.md) 第四节档 1 | 没有实测坏条率 | 在 golden 集上量解析失败率与修复率 | 待校对 |
| 13 | "环境/资料预取"的收益可度量(命中率 × 节省时间),值得排进平台档 2 | 同上,档 2 | 只有直觉,无行业做法与度量口径 | 问外部模型或找 CI 预热类实践 | 待校对 |
| 14 | 等待窗口跑 k=3 旁路采样不会因抢限流额度而拖慢主任务 | 同上,档 3 | 取决于 provider 限流模型,未验证 | 在限流配额下做对照实验 | 待校对 |

## 二、优先级建议

先校 1~5(全是可被一手来源直接裁决的事实,成本最低、收益最大),再校 7(取舍类,需要外部模型给反例),最后 8~11(需要团队自己的实测数据,外部模型只能提供同类实践参考);12~14 来自 [qa/0003](../qa/0003-等待大模型输出时能做什么.md),等有了实测数据再校。

## 版本记录

| 版本 | 日期 | 变更 | 使用模型 |
|---|---|---|---|
| v1 | 2026-10-25 | 从六篇专题中抽出 11 条待校验断言 | DeepSeek(deepseek-flash) |
| v2 | 2026-11-03 | 增补 12~14(流式解析兜底率、预取 ROI、旁路采样与限流),来自 qa/0003 | DeepSeek(deepseek-flash) |
