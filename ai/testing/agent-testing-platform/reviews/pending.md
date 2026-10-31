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

## 二、优先级建议

先校 1~5(全是可被一手来源直接裁决的事实,成本最低、收益最大),再校 7(取舍类,需要外部模型给反例),最后 8~11(需要团队自己的实测数据,外部模型只能提供同类实践参考)。

## 版本记录

| 版本 | 日期 | 变更 | 使用模型 |
|---|---|---|---|
| v1 | 2026-10-25 | 从六篇专题中抽出 11 条待校验断言 | DeepSeek(deepseek-flash) |
