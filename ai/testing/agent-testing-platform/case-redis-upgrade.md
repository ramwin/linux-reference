# 测试智能体实战: 云服务 Redis 5.0 升级 7.0 全流程

```{contents}
```

[智能体测试系统架构](./architecture.md)把"AI 参与测试"拆成了七个阶段,这篇用一句话把它们归拢成测试工程师熟悉的三个词,再用一个完整案例——**公司云服务把 Redis 从 5.0 升级到 7.0**——走一遍每个阶段智能体怎么用、产出什么。

## 三个词与七阶段的对应关系

| 阶段 | 包含的七阶段环节 | 核心问题 | 主要产出 |
|------|----------------|---------|---------|
| **测试策略** | 1 需求理解 | 测什么、不测什么、风险在哪、怎么算通过 | 需求点清单 + 测试策略契约(JSON) |
| **测试设计** | 2 用例生成、3 用例评审、4 脚本生成 | 怎么测、用什么数据、怎么断言 | 编号化用例、分级评审意见、可执行脚本 |
| **测试执行** | 5 用例执行(传统框架,非 AI)、6 失败分诊、7 报告生成 | 实际结果是什么、失败是谁的问题、能不能发布 | 执行结果、分诊结论、测试报告 |

三条贯穿全程的纪律(出处见架构篇,案例里每一步都会体现):

1. **阶段间只传结构化契约,不传对话历史**——下游永远面对确定的 JSON;
2. **生成与评审分离**,用不同模型/不同会话,防止"自己认可自己";
3. **强制证据**:预期结果必须引用文档原文出处,文档没写的标"需澄清",不许编造。

## 案例背景

公司云数据库服务(多租户、按实例计费、主从+哨兵架构)计划把引擎从 Redis 5.0 升级到 7.0。输入给测试智能体的材料:

```
docs/requirements/redis-7-upgrade.md   # 升级需求: 在线热升级、数据不丢、租户无感
docs/api/redis-cloud-openapi.yaml      # 云服务控制台 API(创建/升降级实例等)
docs/redis/5-to-7-changelog.md         # 官方 release notes 整理(兼容性变更清单)
tests/cases/                           # 历史用例库(5.0 时代的存量用例)
docs/errcode/redis-cloud.md            # 云服务错误码表
```

升级的技术风险点(这部分是领域知识,人来准备,写进需求文档):

- **兼容性**: 废弃命令(`SLAVEOF` → `REPLICAOF`、`BRPOPLPUSH` → `BLMOVE`)、行为变更(部分命令返回错误码变化)、RESP3 协议默认不启用但客户端可能协商;
- **数据**: RDB/AOF 版本兼容(7.0 能读 5.0 的 RDB,反之不行——回滚路径是高危点);
- **新特性是否开放**: Function(`FCALL`)、Sharded Pub/Sub、ACL v2 selector——多租户云服务通常要**禁用或隔离**,这本身就是测试点;
- **云服务特有**: 在线升级过程的连接闪断、升级中实例的配额/计费一致性、控制台"升级中"状态机、多租户隔离不因升级破防。

## 第一阶段: 测试策略(对应阶段 1 需求理解)

**智能体干什么**: 读齐所有输入材料,把"升级 Redis"这件模糊的事拆成结构化需求点清单,并给出策略判断——范围、优先级、不测什么、通过标准。

### Prompt(模板库中的 strategy 模板填槽后)

```text
你是资深云服务测试专家。阅读以下材料:
- docs/requirements/redis-7-upgrade.md
- docs/redis/5-to-7-changelog.md
- docs/api/redis-cloud-openapi.yaml
- docs/errcode/redis-cloud.md

为 Redis 5.0 → 7.0 升级输出测试策略, 保存为 tests/strategy/redis-7.json, 要求:
1. 需求点清单: 每条含 id / 描述 / 出处(文件+章节) / 风险等级(P0-P2) / 建议测试类型
2. 策略判断: 测试范围、明确不测的项(给理由)、环境拓扑、发布通过标准(量化)
3. 兼容性变更逐条列出: 废弃命令、行为变更、协议变更, 每条标注对存量租户的影响面
4. 文档没明确说明的行为, 标 "需澄清" 并列出向谁澄清, 不许编造
5. 只输出符合 schema 的 JSON
```

### 输出: 测试策略契约(节选)

```json
{
  "requirement_points": [
    {"id": "RP-01", "desc": "实例在线热升级, 数据零丢失, 业务连接闪断 < 5s",
     "source": "docs/requirements/redis-7-upgrade.md#2.1", "risk": "P0",
     "test_types": ["功能", "可靠性", "性能"]},
    {"id": "RP-02", "desc": "废弃命令 SLAVEOF/BRPOPLPUSH 的兼容策略: 代理层映射或拒绝",
     "source": "docs/redis/5-to-7-changelog.md#deprecated", "risk": "P0",
     "test_types": ["兼容性"], "note": "需澄清: 需求文档未说明代理层是否做命令映射, 找架构组确认"},
    {"id": "RP-03", "desc": "新命令 FCALL/FUNCTION 在多租户下禁用, 调用返回明确错误码",
     "source": "docs/requirements/redis-7-upgrade.md#4.3", "risk": "P1",
     "test_types": ["功能", "安全"]},
    {"id": "RP-04", "desc": "升级失败可回滚到 5.0, 回滚后数据与升级前一致",
     "source": "docs/requirements/redis-7-upgrade.md#2.4", "risk": "P0",
     "test_types": ["可靠性"], "note": "高危: 7.0 写的 RDB 5.0 读不了, 回滚依赖升级前快照"}
  ],
  "scope": {
    "in": ["兼容命令集", "在线升级流程", "回滚", "控制台 API 状态机", "配额计费一致性", "多租户隔离", "性能回归基准"],
    "out": [
      {"item": "Redis Cluster 模式", "reason": "本期产品只卖主从+哨兵形态"},
      {"item": "RESP3 协议", "reason": "服务端默认不启用, 客户端兼容由客户端团队负责"}
    ]
  },
  "environment": "3 套: 5.0 存量实例池 / 升级中实例 / 7.0 新实例池, 每套 3 租户",
  "pass_criteria": "P0 用例 100% 通过; P1 ≥ 95%; 性能回归(基准 ops/sec)退化 < 3%; 升级过程数据一致性校验零差异"
}
```

**人的动作**: 评审策略契约——重点看 `out`(不测的项)和 `需澄清` 条目,这些是 AI 最容易"默默漏掉"的地方。澄清结论(如"代理层做 SLAVEOF→REPLICAOF 映射")回填需求文档后,策略阶段重跑——DAG 节点缓存机制下,只有这一个节点重算。

## 第二阶段: 测试设计(阶段 2-4)

### 步骤 2.1 用例生成(阶段 2)

```text
你是资深云服务测试专家。阅读 tests/strategy/redis-7.json 中 RP-01~RP-04 及引用文档,
为每条需求点设计用例, 保存到 tests/cases/redis-7-upgrade.md, 要求:
1. 每个需求点按矩阵展开: 正常流 / 边界 / 权限(跨租户越权) / 升级中状态 / 回滚路径
2. 兼容性专项: 5-to-7-changelog.md 中每条废弃/变更命令各一条用例, 断言 5.0 与 7.0 行为差异
3. 每条用例: 编号 / 关联需求点 / 前置条件 / 步骤 / 预期结果 / 优先级
4. 预期结果必须引用文档原文出处; 文档没写的标 "需澄清", 不许编造
```

**输出: 用例文件(节选)**

| 编号 | 需求点 | 用例 | 预期结果 | 优先级 |
|------|--------|------|---------|--------|
| TC-0101 | RP-01 | 实例写入 10 万 key 后触发在线升级, 升级前后逐 key 校验 | 数据零差异; 闪断期间客户端自动重连成功(出处: 需求文档 2.1) | P0 |
| TC-0201 | RP-02 | 5.0 和 7.0 实例分别执行 `SLAVEOF host port` | 7.0 返回 "unknown command" 或被代理映射为 REPLICAOF(**需澄清**, 依赖 RP-02 澄清结论) | P0 |
| TC-0207 | RP-02 | 7.0 实例执行 `BRPOPLPUSH k1 k2 0` | 与 changelog 记录的废弃行为一致(出处: changelog#deprecated) | P1 |
| TC-0301 | RP-03 | 租户 A 执行 `FCALL mylib 1 k` | 返回云服务错误码 `Redis.CommandDisabled`(出处: 错误码表 #redis) | P1 |
| TC-0302 | RP-03 | 租户 A 通过 ACL 尝试给自己加 FCALL 权限后调用 | 仍被拒; 且不影响租户 B(越权隔离) | P1 |
| TC-0401 | RP-04 | 升级中注入失败(杀掉 7.0 节点), 触发回滚 | 回滚到 5.0, 数据 = 升级前快照(出处: 需求文档 2.4) | P0 |
| TC-0501 | RP-01 | 升级中查询实例配额与计费计量 | 计量不中断、不重复计费(需求文档未说明计量精度, **需澄清**) | P1 |

### 步骤 2.2 用例评审(阶段 3, 换模型评审)

```bash
claude -p "你是测试评审员, 只审 tests/cases/redis-7-upgrade.md, 不修改任何文件。
对照 tests/strategy/redis-7.json、docs/redis/5-to-7-changelog.md 和错误码表逐项检查:
1. 遗漏: 哪些需求点/废弃命令/错误码没有对应用例
2. 错误: 哪些预期结果与文档矛盾或无出处
每条意见给出 文档出处 + 用例编号, 按 阻断/建议 分级, 不写客套话" \
  --dangerously-skip-permissions --allowedTools "Read,Grep,Glob" \
  > tests/cases/redis-7-upgrade.review.md
```

**输出: 评审意见(节选)**

```text
[阻断] TC-0201 的预期结果仍是"需澄清", 但 RP-02 的澄清结论已回填需求文档 3.2 节
       (代理层映射), 用例未同步更新。出处: docs/requirements/redis-7-upgrade.md#3.2
[阻断] changelog#protocol 列出 "SUBSCRIBE 在事务上下文中行为变更", 无用例覆盖。
[建议] TC-0101 只校验 key 内容, 建议补充 TTL 与 expire 存活校验(7.0 对过期
       删除时机有内部调整, 出处: changelog#expiry)。
[建议] 缺性能回归用例: 策略 pass_criteria 要求 ops/sec 退化 < 3%, 无用例对应。
```

评审意见喂回生成方修订一到两轮,定稿(人工确认)后进入脚本生成。

### 步骤 2.3 脚本生成(阶段 4)

```text
根据 tests/cases/redis-7-upgrade.md 中 P0/P1 用例, 生成 pytest 测试脚本,
保存到 tests/api/test_redis7_upgrade.py, 要求:
- 框架 pytest + redis-py, 连接信息从环境变量读取
- 每个测试标注对应用例编号, 方便回溯
- 禁止修改用例文件和策略 JSON
```

**输出: 可执行脚本(节选)**

```python
import os, redis, pytest

def conn(ver):  # REDIS_50_URL / REDIS_70_URL
    return redis.Redis.from_url(os.environ[f"REDIS_{ver}_URL"])

def test_tc_0201_slaveof_removed():
    """TC-0201: 7.0 上 SLAVEOF 行为(直连引擎, 绕过代理层验证兜底)"""
    r7 = conn("70")
    with pytest.raises(redis.ResponseError):
        r7.execute_command("SLAVEOF", "127.0.0.1", 6379)

def test_tc_0301_fcall_disabled_for_tenant():
    """TC-0301: 多租户下 FCALL 返回云服务错误码"""
    r = conn("70")
    with pytest.raises(redis.ResponseError, match="Redis.CommandDisabled"):
        r.execute_command("FCALL", "mylib", 1, "k")

@pytest.mark.p0
def test_tc_0401_rollback_data_consistency(upgrade_fixture):
    """TC-0401: 注入升级失败, 回滚后数据等于升级前快照"""
    before = snapshot_keys(conn("50"))
    upgrade_fixture.inject_failure(node="redis7-new")
    upgrade_fixture.wait_rollback()
    assert snapshot_keys(conn("50")) == before
```

## 第三阶段: 测试执行(阶段 5-7)

### 步骤 3.1 执行(阶段 5, 非 AI)

执行用传统测试框架和执行机,**智能体不参与判断对错**——这是架构篇的明确边界: 执行是确定性工作,AI 的价值在上下游的设计与归因。执行机跑完产出原始结果:

```text
collected 47 items
tests/api/test_redis7_upgrade.py::test_tc_0201_slaveof_removed PASSED
tests/api/test_redis7_upgrade.py::test_tc_0301_fcall_disabled_for_tenant FAILED
tests/api/test_redis7_upgrade.py::test_tc_0401_rollback_data_consistency FAILED
===== 2 failed, 45 passed in 312.4s =====
```

### 步骤 3.2 失败分诊(阶段 6)

```bash
kimi -p "你是云服务测试失败分诊专家。下面是 Redis 7 升级测试的失败日志和最近 20 条提交。
只输出一个 JSON 对象, 不要 markdown 代码块:
{\"root_cause\": \"一句话根因\", \"evidence\": \"关键日志原文\",
 \"suspect_commits\": [\"hash\"], \"is_flaky\": true/false,
 \"confidence\": 0到1, \"suggested_owner\": \"嫌疑模块\", \"next_action\": \"建议下一步\"}

日志:
$(tail -n 800 ci-failure.log)

最近提交:
$(git log --oneline -20)"
```

**输出: 分诊结论**

```json
[
  {"case": "TC-0301",
   "root_cause": "FCALL 未被禁用而是返回了 Redis 原生 NOAUTH 错误, 疑似代理层命令黑名单配置未下发到 7.0 实例组",
   "evidence": "redis.ResponseError: NOAUTH Authentication required (期望 Redis.CommandDisabled)",
   "suspect_commits": ["a1b2c3d (proxy: command filter 支持按引擎版本分组)"],
   "is_flaky": false, "confidence": 0.85,
   "suggested_owner": "proxy-gateway",
   "next_action": "检查 proxy 命令过滤配置对 engine_version=7.0 分组是否生效"},
  {"case": "TC-0401",
   "root_cause": "回滚后丢失升级窗口内写入的 3 个 key, 快照机制只覆盖升级前数据",
   "evidence": "AssertionError: missing keys {'w:1001','w:1002','w:1003'} — 均为 upgrade_window 期间写入",
   "suspect_commits": [], "is_flaky": false, "confidence": 0.95,
   "suggested_owner": "upgrade-orchestrator",
   "next_action": "这是产品设计问题而非实现 bug: 回滚语义需明确'升级窗口写入是否保留', 升级需求文档"}
]
```

注意第二条: `suggested_owner` 指向了**需求文档**——分诊把"实现 bug"和"需求没定义清楚"区分开,这正是强制证据纪律的回报。confidence 低的条目人工深挖,这两条高置信度直接转缺陷单/澄清单。

### 步骤 3.3 报告生成(阶段 7)

```text
根据本次执行结果与分诊结论(附 JSON), 生成 Redis 7 升级测试报告,
保存到 reports/redis-7-upgrade-2026-W42.md, 要求:
1. 按策略契约的 pass_criteria 逐条判定: 达成/未达成/无法判定(给原因)
2. 每个未达成项附: 用例编号 + 分诊结论 + 缺陷单链接占位
3. 给出发布建议: 通过 / 有条件通过(列条件) / 不通过
```

**输出: 报告结论(节选)**

```text
发布建议: 不通过(P0 阻断 2 项)

| 通过标准 | 结果 | 证据 |
|---------|------|------|
| P0 用例 100% 通过 | 未达成 | TC-0301(缺陷: proxy 黑名单未对 7.0 生效)、TC-0401(回滚丢升级窗口数据) |
| 性能退化 < 3% | 达成 | 基准 142k ops/sec vs 5.0 的 138k, 无退化 |
| 升级数据一致性零差异 | 未达成 | TC-0401 见上 |

需产品决策: 回滚语义是否承诺保留升级窗口写入(RP-04 的语义边界), 决策后更新
需求文档并重跑 RP-04 相关节点。
```

## 收尾: 沉淀回流(飞轮转一圈)

案例跑完不是结束,按"沉淀触发器"纪律,复盘时只问一句"这次有什么值得固化":

| 本次经验 | 沉淀到哪 |
|---------|---------|
| "Redis 类引擎升级测试, 回滚语义必须显式定义升级窗口写入" | 知识层: `docs/playbook/engine-upgrade.md` 新增一节 |
| "代理层配置按引擎版本分组下发" 这个失败模式 | 模板层: 分诊 prompt 加一行判断提示; 长期进 golden 集 |
| 人工定稿的用例与分诊结论 | 抽 10% 回流 golden 评测集, 下次换模型时回归用 |
| TC-0201 这类"依赖澄清结论"的用例写法 | 模板层: 用例生成模板增加"引用需求点澄清状态"字段 |

## 总结

- **测试策略**回答"测什么": 智能体读齐材料产策略契约,人审 `out` 和 `需澄清`;
- **测试设计**回答"怎么测": 生成-评审对抗出用例,再落成脚本,全程编号可回溯;
- **测试执行**回答"结果怎样": 执行交给传统框架,AI 只做失败分诊与报告——**判断对错的权力(oracle)不外包给 AI**,这是三个阶段共同的底线。

## 参考资料

- [智能体测试系统架构: 多智能体协作与模型可替换设计](./architecture.md)——七阶段契约、三种拓扑、golden 集
- [云服务测试的 AI 转型](../cloud-service-testing.md)——用例生成/评审/分诊的 prompt 模板原型
- [Agent 测试系统的意义与"通用 DAG"辨析](./why-agent-testing.md)——为什么测试骨架该用 DAG 定死
- [Redis 7.0 release notes](https://raw.githubusercontent.com/redis/redis/7.0/00-RELEASENOTES)
