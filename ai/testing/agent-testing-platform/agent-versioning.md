# Agent 版本管理:给"优化"和"评测"装一个坐标轴

```{contents}
```

> 一句话:**要做,但版本的对象不是代码,而是"能决定行为的那一整套配置 + 外部状态"**。代码仓只覆盖其中一部分,所以单纯给仓库打 tag 的"版本管理",在 agent 场景里是失效的。

## 一、为什么"做优化"逼着你必须做版本管理

三个绕不开的诉求,每个都指向同一件事:

| 诉求 | 没有版本管理时的表现 | 需要的能力 |
|---|---|---|
| 复现 | 上周那版效果更好,现在复现不出来(不知道当时 prompt 哪一版、模型哪个快照) | 任一条输出能反查到完整行为定义 |
| 归因 | 分数掉了,是 prompt 改动、模型静默升级,还是知识库更新?说不清 | 版本之间可 diff,变化因子可枚举 |
| 回滚 | 上线发现退化,回滚要人肉回忆改了哪几处 | 回滚 = 改一个指针,分钟级生效 |

优化的本质是**受控实验**:你改了 prompt/模型/工具,然后声称"变好了"。这句话成立需要三个条件:其他因子不变(否则不知道是谁的功劳)、度量口径不变(否则分数不可比)、别人能重跑(否则无法验证)。这三条合起来,就是版本管理的定义。

所以问题不是"要不要做",而是"做到什么粒度才够用"。反过来说,什么时候可以先不做:纯 demo、一次性演示、没人会再跑第二次。一旦进入"调优 → 评测 → 上线"的循环,不做就等于每次优化都在赌。

## 二、版本的对象:六个行为因子 + 一个独立坐标轴

agent 的输出由下面这些共同决定,缺一个就复现不了:

| 因子 | 存在哪 | 变更频率 | 版本形式 | 说明 |
|---|---|---|---|---|
| System prompt / few-shot | prompt 仓(git) | 极高 | 文件 sha | 最容易被随手改,也最常背锅 |
| 工具描述与参数 schema | 代码仓(git) | 中 | 文件 sha | tool description 改了,选工具准确率会变——它是"隐性 prompt" |
| 编排图 / 工作流 | git(DAG yaml) | 中 | 文件 sha | 增删节点 = 行为结构变化 |
| 模型 + 采样参数 | 配置 → manifest | 低,但影响最大 | 固定快照号 | 只写别名(`qwen-plus`)不够,供应方换代 = 你的版本变了 |
| 知识库 / 向量索引 | 向量库 + 文档库 | 高(文档天天更新) | 快照 id | 分块参数与 embedding 模型也要记 |
| 安全策略 / 拒答规则 | git | 低 | 文件 sha | 决定"哪些问题不答",本身是评测维度 |
| **评测集**(坐标轴) | git | 只追加 | dataset 版本 | **必须与 agent 版本正交**,不能耦合 |

两条判断:

1. **能被 git 覆盖的进 git,覆盖不了的用 id 钉死**。模型快照、索引快照这类外部状态,靠 manifest 里的一个字段钉住,否则"同一个版本"半年后行为就不一样了;
2. **manifest 本身也进 git**(一版本一文件),数据库只做索引和评测结果。这样"版本的事实源"是 git,"查询与比较"在库里,整个机制不依赖重平台就能跑。

## 三、三档方案

### 方案A:git + manifest 约定(1 天,单人/早期)

- prompt、工具描述、编排图、guardrail 本来就在 git 里,正常 MR 合入;
- 每个"要发布的组合"写一个 `agents/<agent>/versions/<build_id>.yaml`(字段见第四节),记录各因子 sha + 模型快照 + 索引快照;
- 发布时打 tag;评测结果写在 `versions/<build_id>.eval.md` 或一张简单的 run 表;
- 线上配置只认 `build_id`,`latest` 只给本地开发用。

代价几乎为零、不需要新组件;产出是"能回答这版是什么、能不能回滚"。

### 方案B:版本记录 + 评测结果库 + 门禁(1~2 周,团队/要上线)

在 A 之上加四件机器能做的事:

1. 版本记录入库(不可变,只插不改),manifest 规范化为 JSON;
2. 评测结果按 `(版本 × 数据集 × 判官版本)` 入库,**逐条 case 的结果也存**(否则只能看总分,没法 diff);
3. 线上 trace 打上 `agent_version`,失败率按版本聚合 → 能二分定位"从哪版开始变差";
4. CI 门禁:改了哪个因子 → 自动选受影响的评测集 → 跑 → 与基线比 → 过线才许合;灰度按版本权重切流量,带自动回滚条件。

### 方案C:注册中心 + 血缘 + 影子流量(平台期)

- 版本谱系(parent/派生)、跨 agent 依赖图(共享 prompt 片段、共享工具、共享索引);
- 影子流量:新版本旁路跑真实请求,不返回给用户,只对比质量/成本/延迟;
- 自动回滚 + 变更影响分析("改这个共享 prompt 会波及哪 12 个 agent 的哪 7 套评测")。

### 对比

| 维度 | A git+manifest | B 记录库+门禁 | C 注册中心+血缘 |
|---|---|---|---|
| 落地成本 | 1 天 | 1~2 周 | 1~3 人月 |
| 能回答的问题 | 这版是什么、怎么回滚 | 从哪版开始变差、这次改动能不能合 | 改这里会波及谁、线上真实影响多大 |
| 额外组件 | 无 | 版本表 + 评测表 + CI 脚本 + trace 一列 | 平台 + 影子流量通道 |
| 主要坑 | 靠自觉,漏记即失效 | 表设计错了要重跑历史(所以先存逐条结果) | 过早建设,谱系没人维护 |
| 适合 | 1~2 人、日更多次 | 3 人以上、要上线、要能答辩"为什么变好了" | 多团队共用 agent 能力 |

**建议:直接做 B,但不要把 C 当 B 的前提。** B 里真正硬的是四件事——版本记录、逐条评测结果、trace 打标、一条 CI 门禁;其余(UI、谱系、影子流量)等真的有人问"改这个会波及谁"再加。以本平台(七阶段、多角色)的规模,角色数 × 版本数很快到千级,没有表就只剩聊天记录。

## 四、照着抄:最小可用实现

### 4.1 一个版本 = 一个 manifest 文件

`agents/case_reviewer/versions/2026.11.16-1.yaml`:

```yaml
agent: case_reviewer
version: 2026.11.16-1        # 不可变 build id,发布后永不复用
semver_hint: 1.4.0           # 给人看/放进发布单,不参与路由
parent: 2026.11.12-3         # 谱系:用于 diff 与回滚
created_at: 2026-11-16T10:00:00+08:00
created_by: wangx
note: 修复评审漏掉"未覆盖异常分支"的问题

components:
  prompt:
    system:   {ref: prompts/case_reviewer/system.md, sha: 9f2c1ab}
    user_tpl: {ref: prompts/case_reviewer/user.j2,   sha: 4b7e0d1}
  orchestration:
    graph:    {ref: flows/case_reviewer.yaml,        sha: c31a5ee}
  model:
    provider: internal-openai-compat
    name:     qwen2.5-72b-instruct
    snapshot: qwen2.5-72b-instruct-2026-09-30   # 必须能钉住,否则复现不了
    params:   {temperature: 0.1, top_p: 0.9, max_tokens: 4096, seed: 42}
  tools:
    - {name: fetch_requirement, schema_sha: 3d91b7c, desc_sha: 8a0c224}
    - {name: search_case_lib,   schema_sha: 77be102, desc_sha: 5c1f0aa}
  knowledge:
    index_snapshot: kb-2026-11-15-01
    corpus_sha:     e5f0a92
    embedding:      bge-m3-2026-06
  guardrails:
    policy: {ref: guardrails/pii_v3.yaml, sha: 1c9f4aa}

eval:
  dataset:   golden/case_reviewer@v7
  last_run:  run-20261116-1015
  gate:      {contract_pass_rate: 1.00, block_recall: 0.92, cost_cny_per_case: 0.031}
```

三个容易写错的地方:

- `version` 要**不可变**(带日期或递增序号),不要用 `latest` / `v1` 这类会被覆盖的名字;
- `model.snapshot` 必须钉到供应方给的快照号;只有别名时,至少记录"发现变更的日期 + 当时的响应指纹"(见第六节);
- `eval.dataset` 必须写数据集版本,否则这份 manifest 的分数三个月后不可比。

### 4.2 版本号规则:什么时候必须新建版本

| 改动 | semver | 新建运行时版本 | 必须跑哪些评测 |
|---|---|---|---|
| 改 prompt 文案 / few-shot | minor | 是 | 该角色全量 golden |
| 改输出 schema / 工具契约 | major | 是 | 全量 + 下游受契约影响的阶段联调 |
| 换模型 / 换采样参数 | major(风险实际最大) | 是 | 全量 + "同 prompt 换模型"消融对照 |
| 改知识库 / 重建索引 | patch(但必须出快照 id) | 是 | 引用时效性用例 + 全量 |
| 增删编排节点 | major | 是 | 全量 + 端到端链路用例 |
| 纯重构 / 改日志埋点(行为不变) | patch | 否,挂到已有版本 | 抽查 |

判断标准很朴素:**这个改动会不会让同一输入的输出变**。会 → 新版本;不会 → 不建版本,免得版本表爆炸。

### 4.3 表和最小字段

```sql
CREATE TABLE agent_version (
  id            TEXT PRIMARY KEY,        -- 2026.11.16-1
  agent         TEXT NOT NULL,
  parent_id     TEXT REFERENCES agent_version(id),
  manifest      JSONB NOT NULL,          -- 4.1 的规范化 JSON
  manifest_sha  TEXT NOT NULL,           -- 去重,并防"同版本号不同内容"
  status        TEXT NOT NULL CHECK (status IN ('candidate','canary','prod','archived','rolled_back')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by    TEXT NOT NULL
);

CREATE TABLE eval_run (
  id             TEXT PRIMARY KEY,       -- run-20261116-1015
  agent_version  TEXT NOT NULL REFERENCES agent_version(id),
  dataset        TEXT NOT NULL,          -- golden/case_reviewer@v7
  judge_version  TEXT,                   -- 判官也要版本:模型快照 + judge prompt sha
  baseline_run   TEXT REFERENCES eval_run(id),
  metrics        JSONB NOT NULL,
  started_at     TIMESTAMPTZ NOT NULL
);

CREATE TABLE eval_case_result (
  run_id     TEXT NOT NULL REFERENCES eval_run(id),
  case_id    TEXT NOT NULL,
  status     TEXT NOT NULL,              -- pass / fail / judge_disagree
  output_sha TEXT,                       -- 区分"只改格式"与"改了内容"
  diff       JSONB,
  cost_cny   NUMERIC,
  latency_ms INT,
  PRIMARY KEY (run_id, case_id)
);

ALTER TABLE trace ADD COLUMN agent_version TEXT REFERENCES agent_version(id);
```

**存逐条结果的唯一理由**:总分退化时,你要分得清"新版在 3 个 case 上变差、在 2 个 case 上变好"(可能是可接受的取舍),还是"整体轻微下滑"(回归)。只看总分,这两种情况的处置完全相反。

### 4.4 归因:从"分数掉了"到"哪个因子干的"

```
1. 找变差起点   first_bad = 按时间排序后 fail_rate 首次超阈值的版本
2. diff manifest first_bad 与其 parent 的 components 逐项比
3. 因子多于一个 消融复跑:固定其他因子,只把模型/prompt 换回旧值,各跑一次
4. 定位结论    记进该版本 note,并把"这次学到的判据"回流到 golden 集
```

经验判据(用自己的数据校准):

| 现象 | 大概率因子 |
|---|---|
| 契约合规率掉、JSON 解析失败变多 | 模型快照/采样参数(尤其 temperature)、输出 schema |
| 工具完全不调用 / 乱调 | tool description、schema,或上下文被截断 |
| 答法过时、引用旧文档说法 | 知识快照 / 索引重建 |
| 拦截率翻倍但准确率没变 | prompt 变严,或 guardrail 策略变更 |
| 全线一起掉、期间没有代码改动 | 供应方静默升级 → 查快照号与响应指纹 |

### 4.5 CI 门禁(可直接放进流水线)

```python
# scripts/eval_gate.py  —— 过不了就 block merge
import json, sys

RULES = {                       # 阈值集中一处,别散落在脚本里
    "contract_pass_rate": ("min_abs", 1.00),   # 硬门槛:有一例不过就不许合
    "block_recall":       ("min_rel", 0.01),   # 允许比基线低 1pp(噪声)
    "cost_cny_per_case":  ("max_abs", 0.05),
    "p95_latency_ms":     ("max_rel", 0.20),   # 允许慢 20%
}

def check(cand: dict, base: dict) -> list[str]:
    fails = []
    for metric, (kind, limit) in RULES.items():
        cur, ref = cand.get(metric), base.get(metric)
        if cur is None:
            continue
        if kind == "min_abs" and cur < limit:
            fails.append(f"{metric}={cur} < {limit}")
        elif kind == "max_abs" and cur > limit:
            fails.append(f"{metric}={cur} > {limit}")
        elif kind == "min_rel" and ref and cur < ref - limit:
            fails.append(f"{metric}: {ref} -> {cur},退化超过 {limit}")
        elif kind == "max_rel" and ref and cur > ref * (1 + limit):
            fails.append(f"{metric}: {ref} -> {cur},劣化超过 {limit:.0%}")
    return fails

if __name__ == "__main__":
    cand, base = (json.load(open(p)) for p in sys.argv[1:3])
    fails = check(cand, base)
    print("\n".join(fails) or "eval gate passed")
    sys.exit(bool(fails))
```

### 4.6 灰度与回滚:路由认版本,不认 prompt

```yaml
# routing.yaml —— 线上指向"哪个版本"
case_reviewer:
  prod:
    - {version: 2026.11.12-3, weight: 90}
    - {version: 2026.11.16-1, weight: 10}
  rollback_if:            # 满足即把权重切回 100/0,并钉一条告警
    contract_pass_rate: "< 0.98"    # 最近 100 次请求
    human_reject_rate:  "> 0.05"
```

这样"回滚"是一次配置变更,而不是一次代码回退。`git revert` 回答不了"线上此刻用的是哪一版"。

## 五、最容易漏的:评测集自己也要版本

- **case 只增不改**:要改期望输出,就新增 case 并把旧 case 标 `deprecated`。原地改 case 会让"上周 0.82、本周 0.85"的比较彻底失效;
- **dataset 版本参与比较口径**:趋势图 x 轴是时间,但必须标出 dataset 版本;跨版本比分只在同 dataset 内做;
- **判官也版本化**:LLM-as-Judge 的模型快照和 judge prompt 变了,分数同样漂移 → 存进 `eval_run.judge_version`;
- **数据集别塞业务库**:它是资产,git(必要时 LFS)才是事实源,库里只存"跑过的结果"。

这和[总纲里的 golden 集](./README.md)是同一件事的两面:golden 集定义"什么算好",版本管理定义"当时是什么"。缺任一个,另一个都失去意义。

## 六、常见坑

| 坑 | 后果 | 解法 |
|---|---|---|
| 只给代码仓打 tag | prompt 在控制台/数据库里被随手改,版本失真 | prompt 也走 git MR;线上按 sha 加载 |
| 对外说 `v1.0.0`,线上路由却用可变 `latest` | 没人知道线上跑的是哪份 | 路由只认不可变 build id |
| 评测报告不记 run 与数据集版本 | 三个月后无法复现,没法证明"改好了" | 报告带 `run_id + agent_version + dataset + judge_version` |
| 模型别名无声换代 | 一夜之间全线掉分,查不到原因 | 钉快照号;每月做一次"同版本重跑",分数漂移即告警 |
| 版本表爆炸 | 一天几十个版本,评测跑不完 | 分 candidate / prod 两级;候选随便建,nightly 统一回归 |
| 把数据当版本 | 版本库里塞几十 G 索引 | 只存快照 id 或内容 hash,按 id 回取 |
| 回滚靠人回忆 | 事故时长从分钟变小时 | 回滚 = 改 routing 指针 + 一键重跑该版本评测 |
| 让"自动优化脚本"直接改线上 prompt | 版本管理形同虚设 | 自动优化只产出 MR / 候选版本,合入仍需门禁 + 人盖章(见[自进化](./self-evolution.md)) |

## 七、和"优化"闭环的关系

把版本管理接进优化闭环,原来靠感觉的步骤就都变成可执行动作:

| 优化环节 | 接上版本管理之后 |
|---|---|
| 提假设("prompt 补上异常分支要求会更好") | 产出 candidate 版本,manifest 相对 prod 只差 prompt 一个因子 |
| 验证 | 同数据集、同判官跑一次,与 prod 版本逐条 diff |
| 决策 | 质量 + 成本 + 延迟三维比,过门禁才进 canary |
| 上线 | 权重 10% → 30% → 100%,带自动回滚条件 |
| 复盘 | trace 按版本聚合,失败聚类直接挂到版本上,下一轮假设从版本差异里长出来 |

一句话:**版本管理是"优化"这件事的坐标系。没有坐标,所有"变好了"都只是叙事。**

## 八、落地清单(照着打勾)

- [ ] 任一线上 trace 能反查到完整 manifest(版本、各因子 sha、模型快照、索引快照);
- [ ] 任意两个版本能机器 diff 出"哪些因子变了";
- [ ] 回滚 = 改一行 routing 配置,≤10 分钟生效;
- [ ] 评测报告自带 `agent_version + dataset + judge_version`,别人能重跑;
- [ ] 模型记录到快照号(没有就至少响应指纹 + 月度重跑告警);
- [ ] golden 集只增不改,dataset 有版本号,趋势图标注版本;
- [ ] CI 里有一条门禁:契约合规率不足即 block;
- [ ] 有一次完整演练记录:"分数变差 → 二分到版本 → diff 到因子";

前 5 条是硬的,后 3 条是流程;第 8 条最有说服力——真跑过一次,后面都是肌肉记忆。

## 参考资料

- MLflow Model Registry(模型注册表的字段与阶段迁移,可直接类比到 agent 版本):<https://mlflow.org/docs/latest/model-registry.html>
- promptfoo(声明式配置 + CI 跑 prompt/agent/RAG 评测,`eval_gate.py` 的现成替代品):<https://github.com/promptfoo/promptfoo>
- OpenTelemetry GenAI 语义约定(`gen_ai.*` 属性,trace 打标时可复用):<https://opentelemetry.io/docs/specs/semconv/gen-ai/>
- 站内相关:[总纲与 golden 集](./README.md)、[自进化的防退化与灰度](./self-evolution.md)、[架构与不变量](./architecture.md)

## 版本记录

| 版本 | 日期 | 变更 | 使用模型 |
|---|---|---|---|
| v1 | 2026-11-16 | 建立专题:版本对象(六个因子 + 评测集坐标轴)、三档方案对比、manifest/DDL/门禁/灰度回滚实例、坑清单与落地清单 | DeepSeek(deepseek-flash) |

本次消耗:会话 `session-14160842` 汇总输入 7.3 万 / 输出 3.7 万 token(含本次新建全文与构建校验)。
