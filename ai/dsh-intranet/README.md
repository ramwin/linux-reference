# 内网部署 DeepSeek Harness 接入 glm5.3 网关

内网没有外网, 但有:
* 一台大模型网关, 给了 **OpenAI 兼容接口** 和 **Claude(Anthropic Messages) 对接**;
* 模型 `glm5.3`;
* 一台能跑 codeagent 的 Linux 机器。

本文把这台机器变成一台能用的 DSH(DeepSeek Harness): `dsh headless` 能干活,
`dsh web` 能起 GUI, 模型走内网网关的 glm5.3。

> 如果这一步是要**交给内网的 AI 编码 agent 去执行**, 直接给它
> [AGENT-TASK.md](AGENT-TASK.md) —— 那是按"agent 可执行"写的任务书:
> 前置检查、分支决策、硬约束、结构化回报模板, 以及不依赖脚本的手工兜底路径。
> 本文则是给人看的完整方案(原理、实测证据、排查表、compat 归属表)。

## 结论先行

| 问题 | 结论 |
|---|---|
| 用哪种协议接 | **优先 OpenAI 兼容**(pi-ai 路由)。GLM 系有现成方言 `thinkingFormat: zai`, 且请求体干净 |
| Claude 对接能用吗 | 能用。它走 DSH 自家的 Messages 适配器, 但默认会带 3 个 DeepSeek 私有字段, 要按探测结果关掉 |
| 配置写在哪 | `$DSH_HOME/cordis.patch.yml` 的一个受管块, 对所有 profile(web/headless)同时生效 |
| 密钥写在哪 | `$DSH_HOME/.env` 的 `INTRANET_LLM_API_KEY`(名字不能以 `DSH_` 开头, 见下文踩坑 1) |
| 怎么确认成功 | `./dsh-intranet.sh smoke`, 模型回一句话就算通 |

## 前置条件

```bash
node -v      # 必须 v22 及以上(见下)
python3 -V   # 脚本只用标准库; 3.8+ 均可
dsh --version
```

**Node 版本是硬门槛, 而且低版本的失败方式是静默的**: 实测
Node **20.20.2** 上 `dsh` 退出码 0、stdout/stderr 都是 0 字节、连模型请求都不发,
看起来就像"跑完了什么都没干"; 换成 Node **22.23.3** 立刻全绿。所以脚本会在
`doctor` 和每次 `smoke` 前检查 node 主版本, 低于 22 直接标 ❌ 并给出这个解释。
内网机器 node 太旧的话, 把 [Node 官方静态包](https://nodejs.org/dist/) 一起带进去
(`tar -xJf node-v22.x-linux-x64.tar.xz` 后把 `bin/` 加进 PATH, 不用装系统包)。

没有 `dsh` 的话先装, 两条路:

```bash
# A. 内网有 npm 源(Nexus/Verdaccio/内网 registry)
./dsh-intranet.sh install --registry http://npm.intranet/repository/npm/

# B. 内网完全离线: 在有外网的机器上先打包, 再拷进来
./dsh-intranet.sh bundle  --out /tmp/dsh-offline.tar.gz     # 在联网机器上
./dsh-intranet.sh install --bundle /tmp/dsh-offline.tar.gz # 在内网机器上
```

> 离线包本质是 `node_modules` 整包, 和 CPU 架构 / glibc 版本绑定, 目标机同架构才能直接用。
> 本机实测: 496 MB 的 `node_modules` 打成 **117 MB** 的 tar.gz, 解包后
> `dsh --version` 正常, `selftest` 也全绿(见下文"本机验证")。
> 另外实测: profile 首次初始化**不需要联网** —— 新建的
> `$DSH_HOME/profiles/web/` 里 `dependencies` 是空的, `node_modules` 也不会生成,
> 随附 bundle 直接从 DSH 安装目录解析。所以只要 DSH 装上了, 断网起 `dsh web` 没问题。
>
> 包**不含 Node 运行时** —— 内网机器得自己有 node(且 ≥22), 没有的话再带一份
> [Node 官方静态包](https://nodejs.org/dist/) 进去。取不到外网又要跑 DSH,
> 更省事的做法是在内网 registry 上代理一份 `@deepseek-ai/dsh`。

## 三步接通

```bash
cd ai/dsh-intranet

# 1. 探测: 网关在哪个路径、两种协议哪种能用、哪些字段会被拒
./dsh-intranet.sh probe --url http://10.0.0.9:8000 --key sk-xxx

# 2. 配置: 按探测结论写 cordis.patch.yml + .env, 并校验这份配置真能加载
./dsh-intranet.sh configure --url http://10.0.0.9:8000 --key sk-xxx --model glm-5.3

# 3. 冒烟: 真跑一次
./dsh-intranet.sh smoke

# 顺手看看写了什么(密钥打码)
./dsh-intranet.sh show

# 一步体检(环境/配置/网关/冒烟), 输出可以整段贴回来
./dsh-intranet.sh doctor --url http://10.0.0.9:8000 --key sk-xxx
```

`doctor` 是给"出问题要找人看"准备的一条命令: 它把系统与 node/python3 版本、
dsh 位置与版本、`DSH_HOME`、受管块在不在、密钥文件权限与变量名、
网关探测结论、冒烟结果一次性列全, 最后给出 ✅/❌ 汇总, 且**永远不写配置**。

`probe` 会逐个试探这些字段, 把"网关接受什么"变成实测事实而不是猜测:

| 协议 | 试探项 |
|---|---|
| OpenAI 兼容 | 最小 chat 请求、`max_tokens` vs `max_completion_tokens`、`store`、`stream_options`、`reasoning_effort`、`developer` 角色、`strict` 工具、流式 + tools |
| Claude 对接 | 最小 messages 请求、`thinking` 开/关、`output_config`、`dsh_session_log`、`dsh_plugin_packages`、流式 |
| 公共 | `GET /v1/models`(Bearer 与 `x-api-key` 两种鉴权都试), 没带 `--model` 时据此自动挑一个含 `glm` 的 |

被 4xx 拒绝的项, 会自动翻译成对应的 `compat` 开关写进配置; Claude 路由被拒私有字段,
就自动关掉三个 DeepSeek 扩展插件。**探测请求的 `max_tokens` 只有 8**, 花不了多少额度。

`--api openai|anthropic` 可以强制选一种(默认 `auto`: 能用 OpenAI 兼容就用它)。

## 配置落在哪里

DSH 的配置是"多层 patch 依次叠加":

```
@deepseek-ai/dsh-base 等 bundle 层
      ↓
$DSH_HOME/profiles/<profile>/cordis.patch.yml   (profile 层)
      ↓
$DSH_HOME/cordis.patch.yml                      (home 层) ← 脚本只动这里
      ↓
dsh --patch extra.yml                           (命令行覆盖层)
```

home 层对 **所有 profile** 生效, 所以改一次, `dsh headless` 和 `dsh web` 一起生效
(实测 `--dump-config` 两个 profile 里都能看到 `intranet-gw`)。

脚本写进去的是一段被注释包起来的受管块, 重复执行只会替换这一段, 不会越写越多:

```yaml
# >>> dsh-intranet managed block (由 dsh-intranet.sh 维护, 手改会被覆盖) >>>
- id: llm-pi-ai
  config:
    providers:
      intranet-gw:
        displayName: 内网网关
        api: openai-completions
        baseURL: http://10.0.0.9:8000/v1
        apiKeyEnv: INTRANET_LLM_API_KEY
        compat:
          thinkingFormat: zai
        defaultContextWindow: 204800
        defaultMaxTokens: 32768
        models:
          - id: glm-5.3
            name: glm-5.3
            contextWindow: 204800
            maxTokens: 32768
- id: agent-default-model
  config:
    provider: intranet-gw
    model: glm-5.3
# <<< dsh-intranet managed block <<<
```

每次写入前都会备份成 `cordis.patch.yml.bak-<时间戳>`; 如果 DSH 组装配置时报错,
脚本会**自动回滚**并打印报错原文。

### 密钥的解析顺序

DSH 的凭据按固定顺序取, 先命中先赢:

| 顺序 | 来源 | 谁能写 |
|---|---|---|
| 1 | 启动环境(`INTRANET_LLM_API_KEY=xxx dsh`) | 你, 每次启动 |
| 2 | `$DSH_HOME/.credentials.yaml` 凭据存储(GUI 里保存) | 配置界面 |
| 3 | 当前目录的 `.env` | 项目 |
| 4 | `$DSH_HOME/.env` | 脚本写这里 |

脚本写 4, 权限 `600`。想用 CI 注入就加 `--no-key-file`, 自己在启动时 export。

## 两条路由的实测差异

同一台机器、同一个 mock 网关, DSH 0.1.7-rc.2 实际发出的请求体:

| | OpenAI 兼容路由(pi-ai) | Claude 对接路由(llm-deepseek) |
|---|---|---|
| 路径 | `POST {baseURL}/chat/completions` | `POST {baseURL}/v1/messages` |
| 鉴权头 | `Authorization: Bearer <key>` | `x-api-key: <key>` + `anthropic-version: 2023-06-01` |
| 默认输出上限字段 | `max_completion_tokens` | `max_tokens`, 默认值 **256000** |
| 请求体顶层字段 | `model, messages, stream, tools, store, stream_options, max_completion_tokens` | `model, system, messages, stream, tools, max_tokens, thinking, output_config, dsh_session_log, dsh_plugin_packages` |
| 私有字段 | 无 | 3 个 DeepSeek 专属字段, 严格网关会 400 |
| 模型目录 | 自己声明的 `models` 列表 | 自己声明的 `models` 列表(id 原样透传) |
| 思维链方言 | `compat.thinkingFormat` 可选 `zai`(GLM 系) | `output_config.effort`(DeepSeek 私有) |

两条都能跑通(本仓库的 `selftest` 会各跑一遍)。**GLM 系建议走 OpenAI 兼容**:
请求体里没有 DeepSeek 私有字段, 且 pi-ai 原生认识 GLM/Zhipu 的思维链方言。

### `compat` 开关是按协议分的(实测)

`compat` 的键不是通用开关。放错协议的后果是**启动即报错**:

```
dsh: INVALID_CONFIG: llm-pi-ai: provider "intranet-gw" sets compat
     "supportsStrictTools", but no model on the route speaks a protocol
     that takes it; it exists on anthropic-messages
```

要命的是 `--dump-config` 查不出来 —— 它只组装配置树、不加载插件。实测
(dsh 0.1.7-rc.2) 两边各认哪些键:

| 协议 | 合法键 |
|---|---|
| `openai-completions` | `maxTokensField`、`thinkingFormat`、`vllmPriority`、`cacheControlFormat`、`chatTemplateArgs`、`chatTemplateKwargs`、`supportsStore`、`supportsDeveloperRole`、`supportsReasoningEffort`、`supportsUsageInStreaming`、`supportsStrictMode`、`supportsFinishReason`、`supportsThinkingTokenBudget`、`thinkingTokenBudgetField`、`requiresToolResultName`、`requiresAssistantAfterToolResult`、`requiresThinkingAsText`、`requiresReasoningContentOnAssistantMessages`、`supportsLongCacheRetention` |
| `anthropic-messages` | `allowEmptySignature`、`forceAdaptiveThinking`、`supportsCacheControlOnTools`、`supportsEagerToolInputStreaming`、`supportsLongCacheRetention`、`supportsStrictTools`、`supportsTemperature` |
| (`openai-responses` 专属) | `supportsMaxOutputTokens` |

本方案里 Claude 路由走 `llm-deepseek`, **没有 compat 面**, 所以这张表主要约束
OpenAI 兼容路由。`probe_gateway.py` 里内置了这份白名单: 只生成目标协议认的键,
不会把 `supportsStrictTools` 这类 anthropic 专属开关写到 `openai-completions` 上。

因为 `--dump-config` 挡不住这类错误, `configure` 的第 4 步除了组装配置树, 还会
**把刚写的配置复制一份、把 `baseURL` 改成死地址(`127.0.0.1:1`)真启动一次**:
配置有问题会在任何网络 I/O 之前抛 `INVALID_CONFIG`(于是回滚并打印那一行),
配置没问题则只会得到 `TRANSPORT`(连不上死地址)。这样校验**不碰真网关、不发
模型请求**, 却能把插件级错误挡在配置落盘之后、冒烟之前。

## 实测踩过的坑

1. **`.env` 里不能放 `DSH_` 开头的变量名**。DSH 把 `DSH_` / `XDG_` / `DYLD_` 前缀,
   以及 `PATH` / `HOME` / `NODE_*` / `LD_*` 视为"启动引导变量", 只允许由启动环境设置。
   实测直接拒绝启动:

   ```
   Error: dsh: /home/me/.dsh/.env sets "DSH_INTRANET_API_KEY", which only the launching
   environment may set (it decides how this process starts, where its code and
   instructions load from, or how it reaches the network); export DSH_INTRANET_API_KEY
   instead of putting it in a .env file
   ```

   所以默认变量名是 `INTRANET_LLM_API_KEY`, 脚本也会拒绝 `--key-var DSH_*`。
   (顺带: home 层的 `.env` 允许写 `HTTP_PROXY` 等代理变量, 项目层 `.env` 不允许。)

2. **Claude 路由默认输出上限是 256000**。GLM 或中转网关通常没这么大, 会被 400 顶回来。
   配置里显式写 `maxTokens`(默认 32768), 并保证 `contextWindow > maxTokens + 压缩余量`,
   否则开了主动压缩会拒绝启动。

3. **Claude 路由默认会带 DeepSeek 私有字段**: `output_config`、`dsh_session_log`、
   `dsh_plugin_packages`。DeepSeek 官方网关认识, 别人的 Claude 兼容网关多半不认识。
   处置就是配置里 `reasoningEffort: off` + 关掉三个扩展插件:

   ```yaml
   - id: deepseek-llm-api-extensions
     disabled: true
   - id: session-log-deepseek
     disabled: true
   - id: plugin-package-inventory-deepseek
     disabled: true
   ```

   关掉之后请求体只剩 `max_tokens / messages / model / stream / system / thinking / tools`,
   是一份干净的 Anthropic Messages 请求(实测)。

4. **`baseURL` 的 `/v1` 两家语义不同**。`llm-deepseek` 自己会追加 `/v1/messages`
   (末尾正好是 `/v1` 才复用); pi-ai 的 `openai-completions` 是直接拼
   `{baseURL}/chat/completions` 和 `{baseURL}/models`, 所以 baseURL 得含 `/v1`。
   脚本按这个约定归一化: `--url` 填 `http://gw:8000` 或 `http://gw:8000/v1` 都行。

5. **内网代理会劫持探测**。机器上若 export 了 `http_proxy`, 探测内网地址会绕一圈。
   `probe` 默认**绕过**代理直连内网; 确实要走代理再加 `--use-proxy`。

6. **自签证书**。内网网关常用自签 HTTPS, 加 `--insecure` 跳过校验。

## 故障排查

`smoke` 失败时按现象对表:

| 现象 | 多半是 | 处置 |
|---|---|---|
| 启动就 `INVALID_CONFIG` | `compat` 开关放错协议, 或路由字段不认识 | 按上面的归属表改; `configure` 已内置这项校验 |
| 退出码 0 但一个字都没输出 | **node 版本过低**(高发) | `dsh --version` 同样是空的话换 Node 22+; 实测 Node 20 就是这样 |
| `MISSING_CREDENTIAL` | 没拿到 key | 看 `$DSH_HOME/.env` 有没有 `INTRANET_LLM_API_KEY`; 或你在别的 shell export 了但它没进这次启动 |
| `INVALID_CREDENTIAL` / 401 / 403 | key 不对, 或鉴权头不对 | 用 `probe` 看哪个鉴权头是 200 |
| 404 / not found | 路径不对 | `baseURL` 多写或少写 `/v1`, 看 `probe` 报的可用路径 |
| 400 | 网关拒了某个字段 | 重跑 `probe`, 把它标红的项变成配置里的 `compat` 开关 |
| `TRANSPORT: Connection error.` / `ECONNREFUSED` / 超时 | 地址、端口、防火墙、代理 | 先 `curl` 一下网关; 需要代理就 export `HTTPS_PROXY`(home 层 `.env` 允许) |
| 模型回话但内容是乱的 | 思维链方言不对 | GLM 系在 OpenAI 路由里加 `compat.thinkingFormat: zai` |
| GUI 里选不到模型 | 目录里没有这个 id | `models:` 列表里补上, `id` 必须和网关的模型名一致 |

```{note}
机器上设了 `http_proxy` 时, Node 22 会打印一行
`[UNDICI-EHPA] Warning: EnvHttpProxyAgent is experimental`。它只是告警, 不影响请求;
嫌吵就在启动 DSH 时带上 `NODE_NO_WARNINGS=1`(脚本内部调用已自动压掉)。
```

## 不依赖脚本的手工配置

脚本只是把下面两件事做完了, 内网不方便跑 Python 时照抄即可。

**第一步**, 把配置块追加到 `$DSH_HOME/cordis.patch.yml`(没有这个文件就新建,
它就是一个顶层 YAML 数组); **第二步**, 把 key 放进 `$DSH_HOME/.env` 并 `chmod 600`:

```bash
echo 'INTRANET_LLM_API_KEY=sk-xxx' >> ~/.dsh/.env && chmod 600 ~/.dsh/.env
dsh --profile headless --dump-config | grep -A6 'id: llm-pi-ai'   # 能看到内网路由就对了
dsh --profile headless "只回答两个字：正常"                        # 真跑一次
```

Claude 对接版(把上面受管块换成这段):

```yaml
- id: deepseek-llm-api-extensions
  disabled: true
- id: session-log-deepseek
  disabled: true
- id: plugin-package-inventory-deepseek
  disabled: true
- id: llm-deepseek
  name: '@deepseek-ai/dsh-llm-deepseek-api-key'
  config:
    apiKeyEnv: INTRANET_LLM_API_KEY
    baseURL: http://10.0.0.9:8000
    maxTokens: 32768
    reasoningEffort: off
    models:
      - id: glm-5.3
        name: glm-5.3
        contextWindow: 204800
- id: agent-default-model
  config:
    provider: deepseek-official
    model: glm-5.3
```

## Web GUI 也吃同一份配置

`dsh web` 用的就是那个 home 层 patch, 不用另配一份。实测:

```bash
DSH_HOME=/tmp/webhome ./dsh-intranet.sh configure --url http://10.0.0.9:8000 --key sk-xxx
dsh web --host 0.0.0.0 --port 3080 --no-open
# 启动日志会打印带 token 的地址; 打开它, 在模型选择器里挑「内网网关 / glm-5.3」
```

本机验证结果: `dsh web` 用内网配置正常启动并打印
`http://127.0.0.1:3901/?token=…`; 带 token 访问返回 303 换成 cookie,
不带 token 返回 401; 前端 `index.html`(34 KB)与 JS/CSS 资源都是 200。
也就是说 GUI 侧的"进程起得来、认证生效、静态资源齐、配置已加载"这四项都过了,
模型请求本身走的是和 headless 完全相同的那条 LLM 路由(见下)。

## 本机验证: selftest

内网网关不一定随时能动, 所以这套脚本自带一个 mock 网关, 断网也能验证整条链路:

```bash
./dsh-intranet.sh selftest
```

它做四件事: 起 `mock_gateway.py` → 对 mock 跑 `probe` → 在临时 `DSH_HOME` 里
`configure` → `smoke`, **OpenAI 兼容与 Claude 对接两条路由各走一遍**。
全绿说明"配置生成 → 凭据解析 → 协议转换 → 模型回话"这条链没有断,
剩下的风险就只有真网关的行为了。最后还会打印网关侧实际收到的请求:

```
==> 网关侧看到的请求
    DSH 发出的请求 (共 4 条):
        /v1/chat/completions  x2
            请求体字段: max_completion_tokens, messages, model, store, stream, stream_options, tools
        /v1/messages  x2
            请求体字段: dsh_plugin_packages, dsh_session_log, max_tokens, messages, model, output_config, stream, system, thinking, tools
    探测器发出的请求 (共 32 条):
        ...
```

统计按 User-Agent 把"DSH 自己发的"和"探测器发的"分开, 免得把探测请求的字段
误当成 DSH 的字段。上面这份是 **mock 网关什么都接受** 的结果, 所以 DeepSeek 私有
字段被保留了下来; 真网关若拒绝它们, 配置里会自动多出三个 `disabled: true`。

`mock_gateway.py` 同时提供 `POST /v1/messages`(Anthropic)和
`POST /v1/chat/completions`(OpenAI), 并把 DSH 发来的每个请求体原样落到
`/tmp/mock-gateway-requests.jsonl` —— 想知道 DSH 到底发了什么字段, 看这个文件最快。

`selftest --strict` 让 mock 扮演**严格网关**: 它会 400 掉
`max_completion_tokens` / `store` / `stream_options` / `reasoning_effort` /
`developer` 角色 / 工具 `strict`, 以及 Anthropic 侧的所有私有顶层字段。
这一轮跑通, 说明"探测发现被拒 → 关掉对应 compat 开关与插件 → 仍然能干活"
的降级路径是通的。实测严格模式下 DSH 最终发出的请求体收敛成:

```
/v1/chat/completions  x2   请求体字段: max_tokens, messages, model, stream, tools
/v1/messages          x2   请求体字段: max_tokens, messages, model, stream, system, thinking, tools
```

两条路由都验证过之后, 用**离线解包出来的那份 DSH**再跑一遍 `selftest`
(把 `HOME` 指到一个干净目录, 模拟内网目标机), 一样全绿 ——
说明"打包 → 拷进去 → 解包 → 配好 → 跑通"这条离线路径本身没有坑。

```{note}
`selftest` 用临时 `DSH_HOME`, 不会碰你正在用的 `~/.dsh`。
```

## 文件清单

| 文件 | 作用 |
|---|---|
| `dsh-intranet.sh` | 主入口: `probe / configure / smoke / doctor / show / install / bundle / selftest` |
| `probe_gateway.py` | 网关探测器, 输出推荐配置(零依赖) |
| `mock_gateway.py` | 内网网关模拟器, 供离线验证; `--strict` 可扮演严格网关(零依赖) |
| `summarize_requests.py` | 统计 mock 收到的请求路径与字段, 用于核对协议 |
