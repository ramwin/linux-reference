# 从0开始搭建本地 AI 服务(学习用)

```{contents}
```

这篇教程的目标不是"装个软件点两下",而是**理解一个 AI 推理服务由哪些部分组成、每一部分在做什么**。学完之后你会拥有:

1. 一个完全离线、跑在自己电脑上的大模型服务,接口和 OpenAI 官方兼容;
2. 能解释清楚推理服务的完整链路:请求进来后发生了什么、token 是什么、为什么显存会不够用。

```{toctree}
:maxdepth: 2
```

## 一个"AI 服务"由什么组成

先把整个系统的骨架画出来,后面每一步都是往这张图里填东西:

```
+---------+   HTTP 请求(OpenAI 兼容)   +----------------+   权重加载    +------------+
|  客户端  | ------------------------> |    推理引擎     | <----------- |  模型文件   |
| (curl/  | <------------------------ | (llama.cpp/    |              | (GGUF 格式) |
|  网页/   |   HTTP 响应(SSE 流式)     |  Ollama/vLLM)  |              +------------+
| 你的程序)|                           +-------+--------+
+---------+                                   | 读写
                                       +------v-------+
                                       |  GPU / CPU   |
                                       +--------------+
```

四个组成部分:

1. **模型文件**:训练好的权重,本地部署通常用 GGUF 格式(后面细说);
2. **推理引擎**:把模型加载进显存、接收请求、生成 token 的程序。llama.cpp、Ollama、vLLM 都属于这一类;
3. **HTTP API**:引擎对外暴露的服务接口。行业标准是 OpenAI 的 `/v1/chat/completions`——你的服务"兼容 OpenAI 接口",意味着任何 OpenAI SDK 都能直接连上来;
4. **客户端**:任何会发 HTTP 请求的东西——curl、网页、你自己的程序。

## 前置知识:token 与显存

### token 是什么

模型不认字,只认数字。输入文本要先被 **tokenizer(分词器)** 切成一个个 token,每个 token 对应词表里的一个编号:

```
"北京天气怎么样"  ->  [北京, 天气, 怎么, 样]   # 中文 1 个字 ≈ 1~2 个 token
"Hello world"     ->  [Hello, " world"]      # 英文 1 个词 ≈ 1.3 个 token
```

模型做的事情从头到尾只有一件:**根据前面的 token,预测下一个 token**。你的问题、模型的回答、甚至下一篇要讲的"调用工具"动作,全部都是 token 序列。

### 显存估算

模型要跑起来,权重必须全部装进显存(或内存)。粗略公式:

```
显存 ≈ 模型权重 + KV cache + 激活值(通常再预留 10%~20%)
模型权重 ≈ 参数量 × 每参数字节数(由量化精度决定)
```

7B 参数的模型,权重在 fp16 下是 7B × 2 字节 = 14GB。家用显卡(8~24GB)直接装不下,所以本地部署普遍用**量化**。

量化就是把权重从 fp16(每参数 2 字节)压缩到更低精度:

| 量化格式 | 每参数约 | 7B 模型大小 | 质量损失 | 备注 |
|---------|---------|------------|---------|------|
| Q8_0 | 8 bit | ~7.2 GB | 极小 | 接近原始精度 |
| Q6_K | 6 bit | ~5.9 GB | 很小 | 显存紧张时的折中 |
| Q4_K_M | 4.5 bit | ~4.7 GB | 较小 | **日常使用最推荐** |
| Q2_K | 2.6 bit | ~2.9 GB | 明显 | 只有显存实在不够才用 |

```{note}
量化损失的是"细节"而不是"知识":数字精度变低,但模型的组织结构、语言能力还在。Q4_K_M 是社区公认的性价比甜点——质量几乎无感下降,体积砍到 1/3。
```

## 第一步:下载模型

### 安装 huggingface-cli

HuggingFace 是模型文件的事实标准仓库,官方提供了命令行工具:

```bash
pip install -U "huggingface_hub[cli]"
```

### 下载 GGUF 格式的模型

```bash
# 国内网络建议加这一行,走镜像站
export HF_ENDPOINT=https://hf-mirror.com

hf download Qwen/Qwen2.5-7B-Instruct-GGUF qwen2.5-7b-instruct-q4_k_m.gguf
```

说明:

- `Qwen/Qwen2.5-7B-Instruct-GGUF` 是仓库名,社区把量化好的 GGUF 文件放在这种"模型名-GGUF"仓库里;
- 后面是文件名,同一个仓库里通常有 Q2_K 到 Q8_0 各种量化版本,按上表的推荐选 Q4_K_M;
- 本教程统一用 **Qwen2.5-7B-Instruct** 作为示例模型:7B 大小适合学习和家用硬件,中文能力强,支持工具调用(下一篇 Agent 教程要用)。

### safetensors 与 GGUF 的区别

下载模型时你会见到两种格式:

| 格式 | 用途 | 形态 |
|------|------|------|
| safetensors | 训练/微调/研究 | 一个目录,多个分片文件,权重未量化或半精度 |
| GGUF | 推理部署 | 单文件,内嵌 tokenizer + 量化权重 + 元数据 |

GGUF 是 llama.cpp 生态的标准格式:**一个文件包含跑模型所需的全部东西**,拷贝到任何机器上直接就能推理。

## 第二步:从源码编译 llama.cpp

Ollama 之类的工具可以一键装好一切,但既然是"从0开始",我们先亲手编译推理引擎,看看一个推理服务最简形态是什么样。

[llama.cpp](https://github.com/ggml-org/llama.cpp) 是 Georgi Gerganov 开源的 C/C++ 推理框架,目标是"让大模型跑在消费级硬件上"。整个项目没有 Python 依赖,编译产物里有一个 `llama-server` 程序,就是我们要的推理服务。

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp

# 有 NVIDIA 显卡:开 CUDA 支持
cmake -B build -DGGML_CUDA=ON

# 编译(-j 并行,数量填 CPU 核心数)
cmake --build build --config Release -j
```

没有显卡也可以继续:去掉 `-DGGML_CUDA=ON` 就是纯 CPU 推理,7B 模型能跑,只是慢(每秒几个 token)。

```{tip}
编译完成后 `build/bin/` 下有几个工具,和我们的主题相关的是:

- `llama-server`:推理服务(HTTP API);
- `llama-cli`:命令行交互式推理;
- `llama-quantize`:把 fp16 模型量化成 GGUF。
```

### 可选:亲手把模型量化成 GGUF

如果你不只满足于"下载现成的量化文件",可以自己走一遍量化流程:

```bash
# 1. 下载 fp16 的原始模型(safetensors 格式,约 15GB)
hf download Qwen/Qwen2.5-7B-Instruct --local-dir Qwen2.5-7B-Instruct

# 2. 转换成 GGUF(需要 pip install -r requirements.txt,里面主要是 torch)
python convert_hf_to_gguf.py Qwen2.5-7B-Instruct --outfile qwen2.5-7b-f16.gguf

# 3. 量化
./build/bin/llama-quantize qwen2.5-7b-f16.gguf qwen2.5-7b-q4_k_m.gguf Q4_K_M
```

每一步都在做什么:

1. 下载的是模型"出厂状态"——fp16 权重,14GB;
2. 转换只改文件格式(容器),权重数值不变;
3. 量化才真正压缩数值:统计每层权重的分布,把 fp16 数字映射到 4.5 bit 的离散刻度上。信息有损,所以叫"量化损失"。

## 第三步:启动推理服务

```bash
./build/bin/llama-server \
    -m ./qwen2.5-7b-instruct-q4_k_m.gguf \
    --host 0.0.0.0 \
    --port 8000 \
    --ctx-size 8192 \
    --n-gpu-layers 99
```

启动时引擎会先加载权重(几秒到几十秒),之后终端会打印服务地址。`8000` 端口同时提供 HTTP API 和一个网页聊天界面(浏览器打开 `http://localhost:8000` 即可对话)。加 `--metrics` 参数还会在 `/metrics` 暴露 Prometheus 格式的监控指标(生产部署篇会用到)。

参数逐个解释:

| 参数 | 含义 |
|------|------|
| `-m` | 模型文件路径 |
| `--host` | 监听地址。`0.0.0.0` 表示接受局域网访问,只本机用可以写 `127.0.0.1` |
| `--port` | HTTP 端口 |
| `--ctx-size` | 上下文窗口(能处理的 token 总数)。越大能聊的历史越长,但 KV cache 吃显存越多 |
| `--n-gpu-layers` | 放到 GPU 上的层数。`99` 表示"尽量全部放 GPU" |
| `-t` | CPU 线程数(纯 CPU 推理时才有意义) |

```{note}
`--n-gpu-layers` 背后的原理:模型由几十个结构相同的"层"堆叠而成(7B 模型 28 层)。显存足够时全部放 GPU;显存不够时可以把一部分层放回内存用 CPU 算——速度会断崖式下降,但至少跑得起来。这是消费级显卡上跑大模型的常用手段。
```

### 验证服务:curl 测试

```bash
# 查看服务上的模型
curl http://localhost:8000/v1/models

# 发起一次对话
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-7b-instruct",
    "messages": [
      {"role": "user", "content": "用一句话解释什么是KV cache"}
    ],
    "temperature": 0.7
  }'
```

响应长这样(节选):

```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "KV cache 是推理时缓存已计算过的键值对,避免重复计算的机制。"
    }
  }],
  "usage": {
    "prompt_tokens": 14,
    "completion_tokens": 25,
    "total_tokens": 39
  }
}
```

值得注意的字段:

- `usage.prompt_tokens`:你的输入被切成多少个 token;
- `usage.completion_tokens`:回答生成了多少个 token;
- 这是**非流式**响应:服务端把全部回答生成完才一次性返回。稍后会看到流式(`"stream": true`)。

## 第四步:更省事的方案 Ollama

如果编译只是为了理解原理,日常使用可以换 [Ollama](https://ollama.com/)——它内部同样基于 llama.cpp,但把下载、量化选型、模型管理、进程管理全部包掉了:

```bash
# 安装
curl -fsSL https://ollama.com/install.sh | sh

# 拉取模型(自动下载对应量化的 GGUF)
ollama pull qwen2.5:7b

# 启动服务(默认端口 11434)
ollama serve
```

Ollama 同样暴露 OpenAI 兼容接口,把上面 curl 的地址换成 `http://localhost:11434/v1` 即可。唯一的差别是请求里的 model 名要写成 Ollama 的标签(`qwen2.5:7b`)。

| | llama.cpp 手动编译 | Ollama |
|---|---|---|
| 适合 | 学习原理、深度定制、嵌入自己的程序 | 日常使用、快速体验 |
| 模型管理 | 手动下载管理 GGUF 文件 | `ollama pull/rm/list` 自动管理 |
| 定制 | 完全自由(改源码都行) | Modelfile 定义系统提示词、参数 |

## 推理服务内部发生了什么

上面把服务跑起来了,这一节回答"请求进来之后,机器在干什么"。整条链路:

```{mermaid}
flowchart TB
    A[HTTP 请求到达] --> B[tokenize 分词]
    B --> C[prefill 预填充<br/>一次性并行算完所有输入 token]
    C --> D[decode 解码<br/>逐个生成下一个 token]
    D --> E[采样器<br/>按概率从候选里挑一个]
    E --> F{生成完了?}
    F -- 否 --> D
    F -- 是 --> G[detokenize 还原成文本]
    G --> H[流式返回给客户端]
```

> 图示:一次"生成回答"其实是一个循环——每轮只多生成一个 token,把它拼回上下文,再来一轮,直到采样器选出结束符。

### prefill 与 decode 是两个不同的阶段

- **prefill(预填充)**:把输入的所有 token 并行处理,一次性算出整个输入的表示。这个阶段 GPU 算力吃满,是计算密集;
- **decode(解码)**:一个一个地生成新 token。每生成一个,都要读取整个上下文的 KV cache,是显存带宽密集。

为什么区分这两个阶段?因为它们瓶颈完全不同,生产优化(比如连续批处理)正是利用了这个区别。

### KV cache 为什么吃显存

注意力机制里,每个 token 都要"看"上下文里所有其他 token。为了不重复计算,已经算过的 K(键)和 V(值)会被缓存下来——这就是 KV cache。

```
每 token 的 KV cache = 2(K 和 V) × 层数 × KV头数 × 头维度 × 2字节(fp16)
```

以 Qwen2.5-7B 为例:2 × 28 × 4 × 128 × 2 = 57,344 字节 ≈ 56 KB/token。听着不大,但上下文一长:

```
8192 token 上下文 × 56 KB ≈ 450 MB/请求
```

**所以"上下文窗口开多大"和"显存剩多少"是直接挂钩的**:`--ctx-size 8192` 意味着每个请求最多预留 ~450MB 的 KV cache。显存不够时,第一个要砍的就是它。

### 为什么回答的第一个字要等那么久

- 从请求到达,到第一个 token 出现的时间,叫 **TTFT**(Time To First Token)。TTFT 里主要是 prefill 的时间——输入越长,第一个字越慢;
- 之后每个 token 的间隔叫 **TPOT**(Time Per Output Token),decode 阶段基本稳定。

这是所有大模型服务都有的现象,不是你的服务坏了。想确认速度是否正常,看 llama-server 的日志:每轮生成完成后终端会打印类似 `eval time = 1.23s / 30 tokens (41 ms per token, 24 tokens per second)` 的报告。

### 流式输出:SSE

服务端支持把答案"边生成边发回来",协议叫 SSE(Server-Sent Events):

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5-7b-instruct", "stream": true, "messages": [{"role": "user", "content": "你好"}]}'
```

响应是一条条 `data:` 行,每行一个增量 token,最后以 `data: [DONE]` 结束。你用的聊天网页"打字机效果"就是靠它实现的。生产环境里流式输出还有一层实际意义:**用户不用干等完整回答,TTFT 之后内容就持续可见**,体感延迟大幅下降。

## 常见问题排查

### 显存不足(OOM)

启动时或生成到一半报 `CUDA out of memory`。按损失从小到大的顺序处理:

1. 减小 `--ctx-size`(砍 KV cache,见效最快);
2. 换更激进的量化(如 Q4_K_S,注意和 Q4_K_M 是不同文件);
3. 减少 `--n-gpu-layers`,把部分层放 CPU(最慢,但肯定能跑)。

### 生成内容乱码/明显截断

- 上下文不够:输入+输出超过了 `--ctx-size` 设置,提高它(前提是显存够);
- 温度参数不合理:`temperature` 越高输出越随机,写代码、事实问答时调低到 0.1~0.3。

### 速度比预期慢很多

- 确认模型真的跑在 GPU 上:`nvidia-smi` 看显存占用和 GPU 利用率;
- 纯 CPU 推理时 7B 模型每秒几个 token 是正常水平,想快就得用 GPU。

## 下一步

现在你有了一个自己的 AI 服务,但它只会"说话",不会"做事"。下一篇 [从0开始搭建一个 Agent](./agent.md) 会给它装上工具,让它能执行命令、查询信息、自主完成多步任务。
