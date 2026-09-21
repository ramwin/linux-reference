# AI 工作流里的 DAG: 把一条长 prompt 拆成一张可缓存、可重试的图

```{contents}
```

上一篇[云服务测试的 AI 转型](./cloud-service-testing.md)里,用例生成、失败分诊都是"一句 prompt 干一件事"。任务一复杂——比如"分析日志、分类错误、排查嫌疑提交、再写报告"——直觉做法是把所有材料塞进一条长 prompt。这篇文章解释为什么更好的做法是把它拆成一张 **DAG(有向无环图)**,并给出一个 66 行、已实际跑通验证的最小执行器。

## 结论先放在前面

1. **DAG 不神秘**:节点 = 一次调用(LLM 或普通函数),边 = 数据依赖,按依赖拓扑顺序执行。你写的每一个"先 A 再 B 最后 C"的 shell 脚本,手工画出来就是一张 DAG;
2. 它解决一条长 prompt 的四个具体毛病:**错误无法定位、改一处要全量重跑、无依赖的步骤被迫串行、过程不可审计**;
3. 最小 demo 是一个真实问题:CI 构建失败 → 自动产出"错误分类 + 嫌疑提交"分析报告。实测:改一个节点的实现,**只有那个节点重跑**,其余全部命中缓存;
4. **边界**:流程已知、步骤固定的任务用 DAG;流程未知的开放式探索(比如"帮我调查这个诡异 bug")该用 Agent 循环,DAG 套不住它。

## 从一个真实痛点说起

任务:CI 构建失败,要产出一份分析报告——错误有哪些、各是什么类型、最可能是哪个提交引起的。

直觉做法是一条长 prompt:

```text
阅读下面的构建日志和提交列表, 输出一份分析报告: 错误分类统计 + 嫌疑提交。
日志: ...(800 行)
提交: ...(20 条)
```

能用,但有四个毛病,而且随任务复杂度放大:

| 毛病 | 后果 |
|------|------|
| **错误无法定位** | 报告里"嫌疑提交"排错了,你不知道是模型读错了日志、分类错了类型,还是关联逻辑有问题——一个黑盒,里面三段推理纠缠在一起 |
| **改一处全量重跑** | 只想调整报告格式?整条 prompt 重新调 LLM,日志重新读、分类重新做,钱和时间全白花 |
| **无依赖也串行** | "错误分类"和"排查嫌疑提交"互不依赖,一条 prompt 里它们却必须同时做——单次输出的注意力被摊薄,质量反而下降 |
| **过程不可审计** | 中间结论没有独立产物,事后无法复查"当时模型到底看到了什么、判断了什么" |

DAG 就是逐个对症下药的结构:**拆开(可定位)→ 缓存(局部重跑)→ 拓扑排序(并行)→ 中间产物落盘(可审计)**。

## DAG 是什么

DAG(Directed Acyclic Graph,有向无环图):节点是计算步骤,边是"前者的产物作为后者的输入"的依赖关系,且**不允许成环**——不允许 A 依赖 B、B 又依赖 A。

上面的 CI 分析任务画出来就是这样:

```{mermaid}
flowchart LR
    L[构建日志] --> E[提取错误]
    L --> C[提交列表]
    E --> F[错误分类]
    E --> B[排查提交]
    C --> B
    F --> R[分析报告]
    B --> R
```

"错误分类"和"排查提交"是两个无依赖的分支,汇入"分析报告"。环被禁止不是洁癖,是**终止性保证**:执行顺序按拓扑排序展开,图无环 ⇒ 执行必然结束——这是它和 Agent 循环(while not done 那种)最本质的区别。

四种形态放一起对比:

| 形态 | 例子 | 优点 | 致命伤 |
|------|------|------|--------|
| 单条 prompt | 一次性问答 | 零成本上手 | 复杂任务四毛病俱全 |
| 线性链 | prompt chaining,A 输出喂 B | 步骤可复用 | 无并行;中途失败全丢;只能串行重试 |
| Agent 循环 | ReAct:思考→行动→观察→再思考 | 流程自适应,能探索 | 可能死循环;行为不可预测;难以复现 |
| DAG | 本文 | 可定位、可缓存、可并行、必终止 | 流程必须事先知道,不适合开放探索 |

实践中成熟的做法是**分层**:探索阶段用 Agent 循环摸清流程,固化下来的流程改成 DAG 进生产。

## 解决了什么问题: 四个收益逐个验证

以下数据全部来自文末 demo 的真实运行(通过给每个节点注入执行探针统计):

### 1. 局部重跑:改一个节点,只重跑一个节点

```text
== 第 1 次(冷缓存) ==   提取错误 → 排查提交 → 错误分类 → 分析报告   (4 个节点全执行)
== 第 2 次(热缓存) ==   (零执行, 全部命中缓存)
== 第 3 次(只改了"分析报告"的实现) ==   (只有"分析报告"执行, 上游三个节点全部复用)
```

第 3 次运行后报告标题变成新版、内容数据不变——**这正是"调 prompt"的日常**:迭代报告模板时,上游昂贵的 LLM 调用一次都不浪费。

### 2. 并行:无依赖的分支同时跑

冷启动的日志里,"排查提交"先于"错误分类"打印完成——两个节点同属一批就绪节点,被线程池同时调度。分支越多,省的时间越多;这条在 LLM 节点上价值翻倍:三个 30 秒的调用并行,总时长还是 30 秒。

### 3. 可观测:中间产物是落盘的一等公民

每个节点的产物以 JSON 形式存在 `.dag-cache/` 目录里,命名即节点名。报告出错了,先打开上游节点的产物文件,逐环检查"提取的错误行对不对→分类统计对不对",而不是盯着一坨最终输出反推。

### 4. 必终止 + 失败兜底

环会被执行器直接拦下(`存在循环依赖, 无法继续`),从机制上杜绝死循环;单个节点的瞬时失败由节点级重试兜底(demo 实测:前两次调用抛异常、第三次成功,`retries=2` 共尝试 3 次)。这对 LLM 节点格外重要——API 超时、限流是常态,重试应该长在框架里,不该由每个调用点自己操心。

## 最小 Demo: 66 行执行器 + CI 失败分析

三个文件。`dag.py` 是通用执行器,`dag_demo.py` 用真实问题搭一张四节点图,`ci.log` 是模拟的构建日志。

### dag.py —— 拓扑排序 + 线程并行 + 节点级缓存 + 失败重试

```python
"""DAG 执行器: 拓扑排序 + 线程并行 + 节点级缓存 + 失败重试"""
import hashlib
import inspect
import json
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


class Dag:
    def __init__(self, workdir=".dag-cache", retries=2):
        self.nodes = {}          # 节点名 -> {fn, deps, cache}
        self.workdir = Path(workdir)
        self.retries = retries

    def node(self, name, deps=(), cache=True):
        """注册节点: fn 的返回值就是节点的产物"""
        def deco(fn):
            self.nodes[name] = dict(fn=fn, deps=list(deps), cache=cache)
            return fn
        return deco

    def _cache_key(self, name, spec, results):
        # 缓存键 = 节点名 + 节点代码 + 上游产物: 改代码或改输入都会自动失效
        try:
            code = inspect.getsource(spec["fn"])
        except OSError:                       # lambda / 交互式定义的函数没有源码文件
            code = repr(spec["fn"])
        payload = json.dumps([name, code, {d: results[d] for d in spec["deps"]}],
                             sort_keys=True, default=str, ensure_ascii=False)
        return hashlib.sha256(payload.encode()).hexdigest()[:16]

    def run(self, inputs):
        self.workdir.mkdir(exist_ok=True)
        results = dict(inputs)   # inputs 是"没有上游的源节点"
        pending = set(self.nodes)
        with ThreadPoolExecutor(max_workers=8) as pool:
            while pending:
                # 依赖全部就绪的节点, 本批一起跑
                ready = [n for n in pending
                         if all(d in results for d in self.nodes[n]["deps"])]
                assert ready, f"存在循环依赖, 无法继续: {pending}"
                futures = {}
                for n in ready:
                    spec = self.nodes[n]
                    cache_file = self.workdir / f"{n}-{self._cache_key(n, spec, results)}.json"
                    if spec["cache"] and cache_file.exists():
                        results[n] = json.loads(cache_file.read_text(encoding="utf-8"))
                        continue
                    futures[pool.submit(self._run_with_retry, spec["fn"],
                                        *[results[d] for d in spec["deps"]])] = (n, cache_file)
                for fut, (n, cache_file) in futures.items():
                    results[n] = fut.result()
                    cache_file.write_text(json.dumps(results[n], ensure_ascii=False),
                                          encoding="utf-8")
                pending -= set(ready)
        return results

    def _run_with_retry(self, fn, *args):
        for attempt in range(self.retries + 1):
            try:
                return fn(*args)
            except Exception:
                if attempt == self.retries:
                    raise
                time.sleep(1)
```

### dag_demo.py —— 四节点的真实问题

```python
"""真实问题: CI 构建失败, 自动产出一份"错误分类 + 嫌疑提交"的分析报告"""
from dag import Dag

dag = Dag()


@dag.node("提取错误", deps=["构建日志"])
def extract_errors(log: str) -> list:
    return [line for line in log.splitlines()
            if "ERROR" in line or "FAIL" in line]


@dag.node("错误分类", deps=["提取错误"])
def classify(errors: list) -> dict:
    table = {"编译错误": ["cannot find symbol", "error:"],
             "测试失败": ["AssertionError", "Tests run"],
             "部署错误": ["connection refused", "timeout"]}
    stats = {kind: 0 for kind in table}
    for line in errors:
        for kind, keywords in table.items():
            if any(k in line for k in keywords):
                stats[kind] += 1
                break
    return stats


@dag.node("排查提交", deps=["提取错误", "提交列表"])
def blame(errors: list, commits: list) -> list:
    # 最小 demo 用关键词匹配; 换成 AI 后这里是一次 LLM 调用
    hits = [c for c in commits if any(k in c for k in ("UserService", "AuthFilter", "config"))]
    return hits if errors else []


@dag.node("分析报告", deps=["错误分类", "排查提交"])
def report(stats: dict, suspects: list) -> str:
    lines = ["# CI 失败分析报告", "", "## 错误分布"]
    lines += [f"- {kind}: {count} 条" for kind, count in stats.items() if count]
    lines += ["", "## 建议优先排查的提交"] + [f"- {c}" for c in suspects]
    return "\n".join(lines)


if __name__ == "__main__":
    log = open("ci.log", encoding="utf-8").read()
    commits = ["a1b2c3 重构 UserService 的鉴权逻辑",
               "d4e5f6 升级 AuthFilter 依赖",
               "07f8a9 更新 README"]
    results = dag.run({"构建日志": log, "提交列表": commits})
    print(results["分析报告"])
```

### ci.log —— 模拟的构建日志

```text
[INFO] 开始构建 user-service v2.3.1
[INFO] 编译 214 个源文件
[ERROR] /src/main/java/com/acme/UserService.java:[88,23] cannot find symbol: method verifyToken()
[ERROR] /src/main/java/com/acme/AuthFilter.java:[41,9] cannot find symbol: class TokenParser
[INFO] 编译失败, 重试一次
[ERROR] 编译重试仍失败, 终止构建
[INFO] 回滚到上一个可用版本
[ERROR] connection refused: 10.0.3.15:8443, rollback timeout after 30s
```

### 运行

```bash
python3 dag_demo.py
```

输出:

```text
# CI 失败分析报告

## 错误分布
- 编译错误: 2 条
- 部署错误: 1 条

## 建议优先排查的提交
- a1b2c3 重构 UserService 的鉴权逻辑
- d4e5f6 升级 AuthFilter 依赖
```

再把上文"四个收益"里的三次运行实验跑一遍(给节点函数加一行 `print` 作探针即可观察),就能亲眼看到局部重跑和并行生效。

## 把节点换成真正的 AI 调用

demo 里节点是普通函数,换成 LLM 调用只需一个约定:**节点函数 = 一次 `kimi -p` 调用 + JSON 输出**。

```python
import json, subprocess

def ask_kimi(prompt: str, payload: str):
    """节点函数的统一封装: 调用 kimi, 解析 JSON 输出"""
    out = subprocess.run(
        ["kimi", "-p", f"{prompt}\n输入:\n{payload}\n只输出 JSON, 不要 markdown 代码块"],
        capture_output=True, text=True, timeout=600)
    text = out.stdout.strip()
    return json.loads(text[text.find("{"): text.rfind("}") + 1])
```

于是"排查提交"节点从关键词匹配升级成真正的推理:

```python
@dag.node("排查提交", deps=["提取错误", "提交列表"])
def blame(errors, commits):
    return ask_kimi(
        "你是构建失败分析专家。结合错误日志和提交列表找出嫌疑提交, "
        "输出 {\"suspects\": [\"提交说明\"]}",
        "错误:\n" + "\n".join(errors) + "\n提交:\n" + "\n".join(commits),
    )["suspects"]
```

替换之后,前面验证过的四件事——局部重跑、并行、缓存、重试——原样生效,因为它们是执行器的性质,与节点内部是不是 AI 无关。**这正是 DAG 作为 AI 工程结构的价值:AI 只住在节点里,图的纪律由框架保证。**

```{warning}
节点并发调 LLM 时注意服务商的限流:`max_workers=8` 对本地函数无所谓,对 API 可能触发 429。生产上按账户配额给线程池设上限,并善用执行器自带的重试。
```

## DAG 其实一直在你身边

- **Airflow**:数据管道的事实标准,任务依赖即 DAG——AI 工作流的 DAG 热是同一思想在 LLM 时代的重演;
- **LangGraph / Dify / Coze / n8n**:把节点和边做成可视化画布,拖拽生成 AI 工作流,底层都是 DAG 执行器;
- **本目录的 shell 脚本**:[结对编程](./pair-coding.md)的 `pair.sh`、"开发→提交→审查→修复"的循环、[多模型辩论](./multi-model-debate.md)的 `debate.sh`、"提案→批评→修订"——手工写的串行流程,画出来都是两三层的小 DAG。手写的版本没有缓存、没有并行、环靠人脑检查;流程稳定后,值得用执行器固化下来。

## 常见坑

| 坑 | 现象 | 处理 |
|----|------|------|
| 缓存键不含代码版本 | 改了节点逻辑,重跑却拿到旧结果 | 缓存键必须含节点代码(如 `inspect.getsource`)——本文 demo 初版就踩过这个坑,已修复并写进 `_cache_key` |
| 任务拆得太碎 | 节点间传递的数据比计算本身还大,编排开销超过收益 | 合并过小的节点;判断标准:每个节点是否都有独立可评审的产物 |
| 用 DAG 硬套探索性任务 | 流程走不通,反复回头改图 | 探索期用 Agent 循环,流程固化后再 DAG 化 |
| 中间产物不落盘 | 出错只能对着最终输出反推 | 节点产物一律 JSON 落盘,命名即节点名 |
| 下游不处理上游失败 | 一个节点挂了,整图白跑 | 生产级执行器要标记失败节点、跳过其下游并报告;最小版选择直接抛错 |
| 并发打爆 API 限额 | 批量跑 LLM 节点大面积 429 | 线程池按配额设限 + 重试退避 |

## 总结

- **DAG = 节点(一次调用)+ 依赖边 + 拓扑执行**,它把"一条长 prompt"的四个毛病逐个拆掉:错误可定位、改动可局部重跑、无依赖可并行、无环必终止;
- 66 行执行器已经包含生产框架的四个核心机制:拓扑调度、节点缓存、并发执行、失败重试——看懂它,再看 Airflow、LangGraph 都是同一套语言;
- AI 只住在节点里,图的纪律由框架保证;流程未知的任务交给 Agent 循环,流程固化的任务交给 DAG;
- 你手头那些"先 A 再 B 最后 C"的 shell 脚本,就是还没画出来的 DAG。

## 参考资料

- [云服务测试的 AI 转型](./cloud-service-testing.md)——本文 demo 的"排查提交"节点即该文方向三的分诊
- [Kimi Code + Claude Code 结对编程](./pair-coding.md)——`pair.sh` 是手工版两节点 DAG
- [只有一个 Claude Code: 让多个模型讨论方案和 review 代码](./multi-model-debate.md)——`debate.sh` 的"提案→批评→修订"循环
- [从 0 开始搭建一个 Agent](./agent.md)——Agent 循环与 DAG 的互补关系
- [LangGraph 官方文档](https://langchain-ai.github.io/langgraph/)
- [Apache Airflow](https://airflow.apache.org/)
- [Anthropic: Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)——工作流(workflow)与智能体(agent)的权威划分
