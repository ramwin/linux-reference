# 从学习到生产:本地 AI 服务的正式部署

```{contents}
```

前两篇搭好的服务——[本地 AI 服务](./local-ai-service.md) 和 [Agent](./agent.md)——都是"学习形态":单用户、无鉴权、手动启动、挂了重启。这一篇回答:**把它正式部署出去,交给很多用户持续使用时,应该怎么做。**

```{toctree}
:maxdepth: 2
```

## 学习环境与生产环境的差别

| 维度 | 学习环境 | 生产环境 |
|------|---------|---------|
| 用户 | 你自己 | 多人并发,可能全天候 |
| 并发 | 一次一个请求 | 数十上百请求同时 |
| 可用性 | 挂了重启就是 | SLA,如 99.9% |
| 安全 | 无鉴权,绑 localhost | 鉴权、内网、审计 |
| 性能目标 | "能用" | TTFT/TPOT 有明确指标 |
| 变更 | 随便折腾 | 灰度发布、可回滚 |
| 监控 | 看终端日志 | 指标、报警、可视化 |

生产化的核心矛盾只有一个:**GPU 一次只能算一份活,而用户是同时来的。** 后面所有架构设计,本质都是在回答"怎么把有限的 GPU 算力公平、高效、可靠地分给所有用户"。

## 为什么学习用的服务不能直接上生产

llama.cpp / Ollama 默认**一次只服务一个请求**(可以开并行参数,但只是简单的请求级调度)。第二个用户到达时只能排队:

```
请求1: |-------- 生成中 --------|
请求2:                          |-------- 生成中 --------|
请求3:                                           |-------- 生成中 --------|
```

排队本身还能忍,真正浪费的是:**decode 阶段 GPU 计算单元大部分时间在等显存搬运数据,算力利用率只有个位数**。一个请求慢悠悠地吐 token 时,GPU 绝大部分算力闲置着。

```{important}
生产推理引擎的核心思路:**让几十个请求同时 decode,用并发的请求把空闲算力填满**。这叫 continuous batching(连续批处理)——新请求随到随加,完成的请求立刻让位,不互相等待。
```

### continuous batching 与传统批处理

传统批处理等一批请求全部完成才换下一批(短的等长的);continuous batching 则:

```
时间轴 →    t1      t2      t3      t4      t5
请求A:   [======================]
请求B:      [====================]
请求C:          [========]
             ↑ C 完成立即让出位置, 新请求 D 立刻加入
```

> 图示:请求 C 完成后它的显存和算力马上让给新来的请求,不需要等 A、B 结束。批的边界消失了,"批"变成了一个持续流动的池子。

## 生产推理引擎:vLLM

[vLLM](https://docs.vllm.ai/) 是当前生产部署最主流的开源引擎,内置 continuous batching,还解决了另一个生产问题——KV cache 的显存管理。

### PagedAttention:KV cache 的分页管理

回忆第一篇:每个请求的 KV cache 大小由上下文长度决定。如果每个请求都按最大上下文预分配,大量显存被浪费,而且频繁分配/释放会产生碎片。

PagedAttention 的解法类似操作系统的虚拟内存分页:

1. 把 KV cache 切成固定大小的 page;
2. 请求需要多少就分配多少页(不按最大上下文预分配);
3. 释放时按页回收,不产生碎片。

这样显存利用率显著提高,`--gpu-memory-utilization` 也敢安全地拉高。

### 启动 vLLM

```bash
pip install vllm

vllm serve Qwen/Qwen2.5-7B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --max-model-len 8192 \
    --gpu-memory-utilization 0.90 \
    --max-num-seqs 128 \
    --api-key sk-prod-xxxxxxxx
```

参数逐个解释:

| 参数 | 含义 |
|------|------|
| `--max-model-len` | 允许的最大上下文长度。它和 `--max-num-seqs` 共同决定 KV cache 能容纳多少并发请求 |
| `--gpu-memory-utilization` | 显存可用比例(0.90 = 90%)。PagedAttention 让这个值可以安全设高 |
| `--max-num-seqs` | 最大并发请求数。超过则排队 |
| `--api-key` | 鉴权密钥,请求时必须带 `Authorization: Bearer sk-prod-xxxx` |
| `--tensor-parallel-size` | 模型切分到几张卡(单卡 1,双卡 2)。大模型(70B+)必须多卡 |

vLLM 同样暴露 OpenAI 兼容接口,上一篇的 Agent 代码把 `base_url` 换过来即可无缝切换——这正是"OpenAI 兼容"标准的价值。

### 引擎选型对比

| 引擎 | 定位 | 适合场景 |
|------|------|---------|
| llama.cpp / Ollama | 单机、低门槛、消费级硬件 | 学习、个人工具、边缘设备 |
| vLLM | 高吞吐生产推理,生态最成熟 | 标准生产环境(本篇主线) |
| SGLang | 与 vLLM 同档,调度更激进 | 极致吞吐场景 |
| TGI(HuggingFace) | 老牌生产推理 | 深度绑定 HF 生态的团队 |

```{note}
技术选型不用一上来就纠结:学习/单机用 Ollama,生产默认 vLLM,遇到吞吐瓶颈再对比 SGLang。三者接口几乎一致,切换成本主要是部署成本,不是代码成本。
```

## 生产架构

生产环境的分层架构:

```{mermaid}
flowchart TB
    subgraph 客户端
        U1[Web 应用]
        U2[Agent 进程]
        U3[内部脚本]
    end
    subgraph 接入层
        GW[API 网关<br/>nginx / LiteLLM<br/>鉴权 限流 路由]
    end
    subgraph 推理层
        V1[vLLM 副本 1<br/>GPU 0]
        V2[vLLM 副本 2<br/>GPU 1]
        V3[vLLM 副本 3<br/>GPU 2]
    end
    subgraph 支撑层
        MON[Prometheus + Grafana<br/>监控报警]
        REG[模型仓库<br/>权重版本管理]
    end
    U1 --> GW
    U2 --> GW
    U3 --> GW
    GW --> V1
    GW --> V2
    GW --> V3
    V1 -. 指标 .-> MON
    V2 -. 指标 .-> MON
    V3 -. 指标 .-> MON
    REG -. 权重只读挂载 .-> V1
    REG -. 权重只读挂载 .-> V2
    REG -. 权重只读挂载 .-> V3
```

> 图示:三层职责分明——网关管"谁能进来、进来多少",推理层管"生成 token",支撑层管"看得见、换得了"。推理层无状态(权重只读挂载),所以可以随意扩缩容。

各层职责:

| 层 | 职责 |
|----|------|
| 接入层 | 鉴权(API key)、限流、路由、重试、TLS 终结 |
| 推理层 | 纯推理。无状态,可水平扩展 |
| 支撑层 | 监控报警、模型版本管理、日志 |

## 容量规划:一台 GPU 能服务多少用户

### 显存怎么分

第一篇给过公式,生产场景把它细化:

```
显存 = 模型权重 + 单请求 KV cache × 并发数 + 激活值/碎片
```

以 24GB 显卡 + 7B 模型(fp16)为例:

```
权重:                 14 GB
KV cache 可用:        24 × 0.90 - 14 - 约2GB(激活/碎片) ≈ 5.6 GB
单请求 KV cache(8192 上下文): 约 450 MB
最大并发 ≈ 5.6 GB / 450 MB ≈ 12
```

所以 `--max-num-seqs` 不是拍脑袋设的,是显存算出来的。想提高并发,三个方向:

1. **权重量化**(AWQ/GPTQ 等 4bit 方案):权重从 14GB 压到 ~4.4GB,KV cache 可用量从 5.6GB 涨到 ~15GB,并发直接翻三倍;
2. **减小 `--max-model-len`**:短问答场景很有效;
3. **换大显存卡**:A100/H100 的 80GB 相比 24GB,并发翻几倍。

### 吞吐估算

```
吞吐 ≈ 单请求生成速度 × 并发数
```

7B 模型 fp16 在 24GB 卡上,单请求约 30~50 token/s。按 10 个并发、平均每次回答 1000 token 算:

```
10 × 40 token/s = 400 token/s
400 / 1000 = 0.4 次对话/秒 ≈ 每天 3.5 万次对话
```

这是"能不能扛住"的粗算。**真实容量必须压测**——用并发请求打满服务,实测 TTFT、TPOT、吞吐,而不是信估算。

### TTFT 与 TPOT:生产环境的两个 SLA 指标

第一篇埋过这两个概念,生产环境里它们是服务等级目标:

- **TTFT**(Time To First Token):从请求到第一个 token,由 prefill 决定,受输入长度影响最大。典型目标:< 1 秒(2K token 输入);
- **TPOT**(Time Per Output Token):生成阶段每个 token 的间隔,由并发压力决定。典型目标:< 100ms。

```{tip}
流式输出在生产环境不只是体验优化:TTFT 达标时,用户立刻看到内容在生成,"在动"本身就是可用性的一部分。非流式的等待体感是 1+1=3。
```

## 安全

生产 AI 服务的安全有几层,从外到内:

1. **网络**:推理服务只绑内网,不直接暴露公网。TLS 终结在网关;
2. **鉴权**:vLLM `--api-key` 是最后一道闸,生产一般由网关统一做 API key 管理、配额;
3. **提示词注入**:Agent 场景特有(上篇讲过原理)。生产对策:工具最小权限 + 沙箱 + 高危操作人审 + 工具输出校验;
4. **数据**:本地部署的最大价值就是数据不出内网。仍然要做的:日志脱敏(用户输入进入日志前先过滤敏感信息)、保留审计记录。

## 监控与可观测性

vLLM 自带 Prometheus 格式的 `/metrics` 端点,配一套 Prometheus + Grafana 即可看到服务全貌:

| 指标 | 含义 | 建议报警条件 |
|------|------|-------------|
| `vllm:time_to_first_token_seconds` | TTFT | P95 > 2s |
| `vllm:time_per_output_token_seconds` | TPOT | P95 > 100ms |
| `vllm:num_requests_waiting` | 排队中的请求 | 持续 > 0 |
| `vllm:num_requests_running` | 正在处理的请求 | 持续等于上限 |
| `vllm:gpu_cache_usage_perc` | KV cache 使用率 | > 90% |
| `vllm:prompt_tokens_total` / `vllm:generation_tokens_total` | 输入/输出流量 | 容量规划依据 |

网关层(nginx)再补上请求数、错误率、P99 延迟。两层数据放一起,出问题时才能分清:是模型慢了(TTFT/TPOT 上升),还是网关挡了(限流、连接问题)。

```{note}
报警阈值是压测出来的,不是抄来的。上线前先打一轮压测,记录饱和点,再把报警设在饱和点的 70%~80%。
```

## 高可用与发布

- **多副本**:推理服务无状态,天然适合多副本 + 负载均衡。一台 GPU 挂了,网关自动踢掉它,流量走其余副本;
- **健康检查**:vLLM 提供 `/health` 端点,容器编排用它做存活/就绪探测;
- **灰度发布**:换新模型时,先切 10% 流量到新版本,对比 TTFT/TPOT 和输出质量,没问题再逐步全量。模型的"质量回归"靠指标看不太出来,灰度期要人工抽查;
- **回滚**:权重以只读方式挂载、模型名版本化。回滚 = 换回旧挂载,一分钟的事。永远不要在发布新模型时删除旧模型文件。

## Kubernetes 部署示例

生产环境一般跑在 Kubernetes 上,最小部署长这样:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-qwen
spec:
  replicas: 2  # 两个 GPU 副本
  selector:
    matchLabels:
      app: vllm-qwen
  template:
    metadata:
      labels:
        app: vllm-qwen
    spec:
      containers:
        - name: vllm
          image: vllm/vllm-openai:latest
          args:
            - "Qwen/Qwen2.5-7B-Instruct"
            - "--max-model-len"
            - "8192"
            - "--gpu-memory-utilization"
            - "0.90"
            - "--max-num-seqs"
            - "128"
          env:
            - name: VLLM_API_KEY
              valueFrom:
                secretKeyRef:
                  name: vllm-secret
                  key: api-key
          ports:
            - containerPort: 8000
          resources:
            limits:
              nvidia.com/gpu: 1  # 每副本一张卡
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-qwen
spec:
  selector:
    app: vllm-qwen
  ports:
    - port: 8000
      targetPort: 8000
```

要点:

- 权重由镜像内置或启动时拉取到共享存储,推理层不落任何可变数据;
- 扩容方式与普通无状态服务相同(replicas +1)。区别是 **GPU 机器贵且少,扩缩容通常手动做**——小规模用 HPA 按 GPU 利用率自动扩容反而危险;
- 网关、监控、模型仓库作为独立组件部署,不随推理副本变动。

## 成本

生产部署的账要算清楚。以 7B 模型为例:

| 方案 | 硬件 | 单卡约 | 适合 |
|------|------|--------|------|
| 消费级 GPU 自建 | RTX 4090(24GB) | 购买约 1.5~2 万(一次性) | 小团队内部使用 |
| 云 GPU 按需 | A10/A100(24~80GB) | 每小时数元~数十元 | 波动负载、快速验证 |
| 云 GPU 包月/年 | A100/H100 | 每月数千~数万 | 稳定生产负载 |

省钱的两个方向:

- **量化**:4bit 权重(AWQ/GPTQ)把 7B 权重从 14GB 压到 ~4.4GB,同样的卡能服务更多并发,相当于省钱;
- **投机解码**(speculative decoding):小模型"起草"、大模型"校对",生成速度可翻倍。vLLM/SGLang 都支持,作为优化项后置。

```{warning}
消费级显卡(4090 等)与数据中心卡(A100/H100)的差距不只是算力:数据中心卡显存更大、支持虚拟化、厂商稳定性更好,且云厂商对消费卡的 SLA 几乎为 0。内部小规模使用消费卡没问题,对外服务请用数据中心卡。
```

## 上线检查清单

- [ ] 鉴权开启,服务只绑内网
- [ ] 监控与报警就位,阈值来自压测
- [ ] 至少两个副本,验证过故障切换
- [ ] 灰度发布流程演练过,旧模型未删除
- [ ] 压测出真实的 TTFT/TPOT/吞吐,与容量规划核对
- [ ] Agent 工具权限已按最小权限收口,沙箱就位
- [ ] 日志脱敏、审计开启
- [ ] 成本预估与预算对齐

## 总结

三篇文章串起来是一条完整的路:

1. [从0搭建本地 AI 服务](./local-ai-service.md):理解服务是什么——模型文件、推理引擎、HTTP 接口;
2. [搭建 Agent](./agent.md):给模型装上工具和循环,让它从"会说话"到"会做事";
3. 本篇:把学习形态推向生产——换连续批处理引擎、分层架构、监控、安全、成本。

原理上,生产环境没有新魔法:还是那套"权重 + 引擎 + OpenAI 兼容接口",变化的只是并发、可靠性和治理。
