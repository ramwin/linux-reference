# 内网 DSH 接入任务书(交给内网编码 agent 执行)

> 读者: 一个运行在公司内网、有 bash 与文件读写能力的编码 agent(Claude Code 之类的形态)。
> 执行环境: 内网 Linux 机器, 能访问公司的大模型网关, **没有外网**。
> 目标: 让这台机器上跑起 DeepSeek Harness(DSH), 模型走内网网关的 `glm5.3`。
> 预计耗时: 15 分钟以内(不含装 Node/npm)。

---

## 0. 你的任务与成功判据

把本机的 DSH 接到内网大模型网关上, 然后**真跑一次**证明它通了。

成功判据(必须实际执行并看到结果, **不要只报告"配置已写入"**):

1. `dsh --profile headless "只回答两个字：正常"` 能打印出模型回复;
2. 或者 `./dsh-intranet.sh doctor --url <网关地址> --key <key>` 最后一行是
   `✅ doctor 全绿: 这台机器上 DSH + 内网网关已经能用。`

已知条件: 网关提供 **OpenAI 兼容接口** 与 **Claude(Anthropic Messages)对接** 两种口子,
模型是 `glm5.3`; 网关地址与 API Key 由人类提供给你。

---

## 1. 前置检查(先做, 不要跳过)

```bash
uname -srm
node -v
python3 -V
command -v dsh && dsh --version
uname -m
```

判定表:

| 检查项 | 要求 | 不满足怎么办 |
|---|---|---|
| `node -v` | **必须 ≥ v22** | ⚠️ 见下方警告。让人类装 Node 22+, 或解压官方静态包 `node-v22.x-linux-x64.tar.xz` 并把 `bin/` 加进 PATH |
| `python3` | ≥ 3.8, 只用标准库 | 没有就走文末的附录 B(手工路径) |
| `dsh` | 能找到 | **注意: `command -v dsh` 找不到不代表没装** —— 脚本会自动在 `~/node_modules/@deepseek-ai/dsh`、`/usr/lib/node_modules/...` 等常见位置找, 找不到时 `selftest` 会报出它实际用的路径。真的没装才 `./dsh-intranet.sh install --registry <内网npm源>`; 完全离线用 `--bundle` |
| 网关连通 | `curl` 得通 | 不通先解决地址/端口/防火墙/代理, 别往下走 |
| `LANG` / locale | 不用管 | `zh_CN.GBK` 这类非 UTF-8 locale 脚本已自动处理(强制 Python UTF-8 模式), 不要手动去改 locale |

> ⚠️ **Node 20 是静默陷阱**: 实测 Node 20.20.2 上 `dsh` 退出码是 **0**,
> stdout 与 stderr 都是 **0 字节**, 网关侧一条请求都不会收到 —— 看起来像"跑完了什么都没干"。
> 换成 Node 22.23.3 立刻正常。所以: `node -v` 低于 22 时, **不要**试图
> "再试一次"或"多等等", 直接换 Node。

自签证书的网关:

```bash
curl -k -sS -o /dev/null -w '%{http_code}\n' https://<网关>/v1/models -H 'Authorization: Bearer <key>'
```

---

## 2. 主路径: 三条命令

先确认你手上有 `ai/dsh-intranet/` 目录(与本文件同级)。
**先自检脚本本身**, 再动真网关:

```bash
cd ai/dsh-intranet
./dsh-intranet.sh selftest          # 本机起 mock 网关, 不碰真网关、不花额度
```

`selftest` 期望最后一行是 `✅ selftest 通过: ... 两种路由全通。`
若它就没过, 说明本机 DSH 或 Node 有问题, 先解决, 不要进入下一步。

想更彻底一点(尤其是怀疑脚本本身有问题时), 跑这一条:

```bash
./dsh-intranet.sh verify     # 10 个用例: 协议形态 / GBK locale / 凭据方式 / 边界拒绝
```

它同样不碰真网关。全绿就说明"工具箱本身没问题", 后面出问题基本都出在网关上。

然后接真网关:

```bash
# 1) 探测: 网关在哪个路径、两种协议哪种能用、哪些字段会被拒(只发 max_tokens=8 的小请求)
./dsh-intranet.sh probe --url <网关地址> --key <key>

# 2) 配置: 按探测结论写 $DSH_HOME/cordis.patch.yml + .env, 并校验配置真能加载
./dsh-intranet.sh configure --url <网关地址> --key <key> --model glm5.3

# 3) 一键体检 + 冒烟(输出整段留档, 这是你要交回去的报告主体)
./dsh-intranet.sh doctor --url <网关地址> --key <key>
```

常用参数(全部可选):

| 参数 | 什么时候用 |
|---|---|
| `--api openai|anthropic` | 强制选一种口子; 默认 `auto`(能用 OpenAI 兼容就用它) |
| `--model ID` | 网关上的确切模型 id; 不传则从 `/v1/models` 里挑含 `glm` 的 |
| `--insecure` | 网关是自签 HTTPS(只影响**探测**; DSH 那边要 `--ca-file`) |
| `--ca-file FILE` | 自签 HTTPS 网关的 CA 证书: 探测与 DSH 都会信任它(推荐) |
| `--use-proxy` | 探测时**要走** `http_proxy/https_proxy`(默认绕过代理直连内网) |
| `--no-key-file` | 不写 `.env`, 由你自己 export 凭据变量(名字见配置里的 `apiKeyEnv`, 默认 `INTRANET_LLM_API_KEY`) |
| `--key-var NAME` | 换一个凭据变量名(默认 `INTRANET_LLM_API_KEY`); 生成的配置与 `.env` 会一起跟着换 |
| `--max-tokens N` | 单次输出上限, 默认 32768(必须小于网关允许值) |
| `--context-window N` | 模型上下文窗口, 默认 204800 |
| `--dsh-home DIR` | 换一个 DSH 家目录(默认 `$DSH_HOME` 或 `~/.dsh`) |
| `--profile NAME` | 校验/冒烟用的 profile, **保持默认 headless**; 传 `web` 会被冒烟拒绝(它常驻) |
| `--strict` | 只给 `selftest` 用: 让 mock 扮演"严格网关"验证降级路径 |

**推荐用 OpenAI 兼容口子**: pi-ai 路由有 GLM/Zhipu 的原生思维链方言(`thinkingFormat: zai`),
且请求体里不带 DeepSeek 私有字段。

---

## 3. 分支决策

按顺序判断, 命中一条就走对应分支:

1. **网关只有 OpenAI 兼容** → `configure --api openai`
2. **网关只有 Claude 对接** → `configure --api anthropic`
   (会自动在配置里 `disabled` 掉三个 DeepSeek 扩展插件、把 `reasoningEffort` 设为 `off`)
3. **网关是自签 HTTPS** → 一律加 `--ca-file /path/to/ca.pem`(探测和 DSH 都要信)。
   注意 `--insecure` 只让探测不校验证书, **DSH 是独立 Node 进程, 它仍会失败**,
   而且只报 `TRANSPORT: Connection error.`, 看起来像防火墙问题。
4. **网关拒掉某些字段** → 什么都不用做: `probe` 已经把它们翻译成 `compat` 开关写进配置了。
   看 `probe` 输出里 `注意: 网关拒绝 xxx, 已关闭 compat.yyy` 那几行。
5. **`probe` 报"流式"是 ❌** → 该口子不可用(DSH 的模型请求走 SSE 流式), 换另一种协议或换网关,
   **不要**试图用非流式凑。
6. **模型 id 不确定** → 不传 `--model`, 或先 `curl <网关>/v1/models -H "Authorization: Bearer <key>"`
7. **没有 python3** → 走文末的附录 B(手工路径)
8. **没有 dsh** → `./dsh-intranet.sh install --registry <内网 npm 源>`;
   **没有 root 或不想装全局** → 加 `--prefix ~/dsh`(装完自动软链到 `~/.local/bin/dsh`,
   脚本自己认这个入口, 不需要改 PATH);
   完全离线时在有外网的机器上 `./dsh-intranet.sh bundle --out dsh-offline.tar.gz`,
   拷进来后 `install --bundle dsh-offline.tar.gz`(包与 CPU 架构/glibc 绑定, 需同架构)

---

## 4. 硬约束(必须遵守)

1. **密钥处理**: key 只允许出现在 `$DSH_HOME/.env`(权限 `600`)或启动环境变量里。
   不要 `echo` 它、不要写进任何提交、**报告里必须打码**(只写前 4 位)。
2. **只改两个文件**: `$DSH_HOME/cordis.patch.yml`(里面的受管块)与 `$DSH_HOME/.env`。
   其余配置文件一律不要动; 脚本写之前会自动备份, 校验失败会自动回滚。
3. **不要动 `$DSH_HOME` 之外的东西**, 不要为通过检查而修改 DSH 自身代码。
4. **不要伪造结论**: 跑不通就如实报告现象与原始报错, 这比"看起来成功了"有价值得多。
5. **不要联网**: 内网环境不要尝试 `pip install` / `npm install` 拉公网包(内网源除外)。
6. 报告里的命令输出**原样保留**, 不要"帮我总结成一句没问题"。

---

## 5. 已知的坑(已经踩过, 不要重复)

| 现象 | 真正原因 | 处置 |
|---|---|---|
| `dsh` 退出码 0 但一个字都不输出 | **Node < 22**(静默失败, 连请求都不发) | 换 Node 22+ |
| `.env` 里写 `DSH_XXX=...` 后 DSH 直接拒绝启动 | DSH 不允许 `.env` 设置 `DSH_`/`XDG_`/`DYLD_` 前缀与 `PATH`/`NODE_*` 这类"启动引导变量" | 用 `INTRANET_LLM_API_KEY` 这个名字 |
| 网关 400, 说 `max_tokens` 超限 | Claude 路由默认输出上限是 **256000** | 配置里显式 `maxTokens: 32768` |
| 网关 400, 说字段不认识 | Claude 路由默认会带 `output_config`、`dsh_session_log`、`dsh_plugin_packages` 三个 DeepSeek 私有顶层字段 | 让 `probe` 判定后自动关掉(配置里三个 `disabled: true`) |
| 启动即 `dsh: INVALID_CONFIG: ... sets compat "xxx", but no model on the route speaks a protocol that takes it` | `compat` 的键**按协议分流**, 放错协议了 | 见下方"compat 归属" |
| 404 / not found | `baseURL` 的 `/v1` 写法不对(两种协议语义不同) | 重跑 `probe`, 看它报的可用路径; 脚本已归一化 |
| 连接超时/被劫持 | 机器上设了 `http_proxy` | 探测默认绕过代理直连; 确实要走代理加 `--use-proxy` |
| `probe` 用 `--insecure` 过了, 但 `smoke` 报 `TRANSPORT: Connection error.` | 探测与 DSH 是**两套 TLS**: `--insecure` 只作用于探测 | 加 `--ca-file /path/to/ca.pem`; 拿不到 CA 才用 `export NODE_TLS_REJECT_UNAUTHORIZED=0` |
| GUI 里选不到模型 | 模型 id 与网关不一致 | `models:` 列表里的 `id` 必须与网关模型名完全一致 |

**compat 归属(手工改配置时必看)**: `openai-completions` 路由只认
`maxTokensField`、`thinkingFormat`、`vllmPriority`、`cacheControlFormat`、
`chatTemplateArgs`、`chatTemplateKwargs`、`supportsStore`、`supportsDeveloperRole`、
`supportsReasoningEffort`、`supportsUsageInStreaming`、`supportsStrictMode`、
`supportsFinishReason`、`supportsThinkingTokenBudget`、`thinkingTokenBudgetField`、
`requiresToolResultName`、`requiresAssistantAfterToolResult`、`requiresThinkingAsText`、
`requiresReasoningContentOnAssistantMessages`、`supportsLongCacheRetention`;
`supportsStrictTools`、`supportsTemperature`、`forceAdaptiveThinking`、
`allowEmptySignature`、`supportsEagerToolInputStreaming`、`supportsCacheControlOnTools`
属于 `anthropic-messages`, **写到 OpenAI 路由上会启动失败**;
`supportsMaxOutputTokens` 属于 `openai-responses`。
另外: Claude 路由走 `llm-deepseek`, 没有 `compat` 面, 不需要也不该给它加 `compat`。

DSH 实际发出的请求体(实测, 可用来和网关日志对照):

```
OpenAI 兼容:  POST {baseURL}/chat/completions   Authorization: Bearer <key>
              max_tokens | max_completion_tokens, messages, model, stream, tools, (store, stream_options)
Claude 对接:  POST {baseURL}/v1/messages        x-api-key: <key> + anthropic-version: 2023-06-01
              max_tokens, messages, model, stream, system, thinking, tools
```

---

## 6. 你要交回去的报告(结构化模板)

跑完 `doctor` 后, 把下面模板填好并连同**原始输出**一起交回。缺项就写"未执行/失败原因", 不要留空。

````text
## 内网 DSH 接入报告

### 1. 环境
- 机器/系统:
- 架构:
- node -v:                       (低于 22 请注明"已换/未换")
- python3 -V:
- dsh 版本与路径:

### 2. 网关探测结论
- 网关地址(可打码):
- 可用协议:
- 模型 id:
- `probe` 输出里所有 `注意:` 行(原样粘贴):

### 3. 落盘的配置
- $DSH_HOME/cordis.patch.yml 的受管块(原样粘贴; key 不会出现在里面):
- $DSH_HOME/.env 里设置了哪些变量名(`./dsh-intranet.sh show` 的输出已把值掩成 `***`, 可整段粘贴):
- 密钥文件权限(stat -c '%a'):

### 4. 冒烟结果
- 命令:
- 模型实际回复(原样):
- 退出码:

### 5. 失败项(没有就写"无")
- 现象:
- 原始报错(整段):
- 你试过的处置与结果:

### 6. 你额外做的改动(没有就写"无")
- 改了哪些文件、为什么:

### 7. doctor 完整输出
(整段粘贴)
````

---

## 5.5 可选: 看一眼 Web GUI

如果这台机器上要给人用图形界面:

```bash
dsh web --host 0.0.0.0 --port 3080 --no-open
```

启动日志会打印一个带 token 的地址, 打开它, 期望看到:

1. 页面正常打开(不是白屏/401);
2. 模型选择器里能选到「内网网关 / <模型 id>」;
3. 发一句"你好"能收到回复。

对不上的话: 选择器里没有模型 → `models:` 里的 `id` 与网关模型名不一致;
有模型但发不出去 → 回去看 `probe` 里被标 ❌ 的字段与它对应的 `compat` 结论。

## 附录 A: 文件清单与期望布局

```
ai/dsh-intranet/
├── AGENT-TASK.md          # 本文件
├── README.md              # 给人看的完整方案(含 compat 归属表、手工配置法)
├── dsh-intranet.sh        # 主入口: probe/configure/smoke/doctor/show/install/bundle/selftest
├── probe_gateway.py       # 网关探测器(零依赖, 输出推荐配置与 compat 开关)
├── mock_gateway.py        # 网关模拟器(零依赖, --strict 可扮演严格网关)
└── summarize_requests.py  # 统计 mock 收到的请求字段
```

子命令速查:

```bash
./dsh-intranet.sh verify                 # 10 项验收(不碰真网关)
./dsh-intranet.sh selftest [--strict]   # 快速自检(不碰真网关)
./dsh-intranet.sh probe    --url U --key K
./dsh-intranet.sh configure --url U --key K [--model M]
./dsh-intranet.sh smoke                 # 真跑一次
./dsh-intranet.sh doctor   --url U --key K
./dsh-intranet.sh show                  # 打印受管块; .env 里每一行赋值都会被掩成 ***, 可安全贴进报告
./dsh-intranet.sh install  --registry URL | --bundle FILE
./dsh-intranet.sh bundle   --out FILE   # 在有外网的机器上打包
```

---

## 附录 B: 不依赖脚本的手工路径

没有 python3(或不想跑脚本)时, 用 `curl` + 手写 YAML 也能完成, 步骤等价。

**第 1 步: 判断网关路径与协议**(把 `<GW>`、`<KEY>` 换成实际值):

```bash
# OpenAI 兼容口子(模型列表 + 一发最小请求)
curl -sS <GW>/v1/models -H "Authorization: Bearer <KEY>"
curl -sS <GW>/v1/chat/completions -H "Authorization: Bearer <KEY>" -H 'Content-Type: application/json' \
  -d '{"model":"glm5.3","messages":[{"role":"user","content":"ping"}],"max_tokens":8}'

# Claude 对接口子
curl -sS <GW>/v1/messages -H "x-api-key: <KEY>" -H 'anthropic-version: 2023-06-01' \
  -H 'Content-Type: application/json' \
  -d '{"model":"glm5.3","max_tokens":8,"messages":[{"role":"user","content":"ping"}]}'
```

哪个返回 2xx 就用哪个。若返回 400 并点名某个字段, 记录字段名, 第 3 步按需关闭对应开关。

**第 2 步: 写密钥**(变量名**不能**以 `DSH_` 开头):

```bash
mkdir -p ~/.dsh
printf 'INTRANET_LLM_API_KEY=<KEY>\n' >> ~/.dsh/.env
chmod 600 ~/.dsh/.env
```

**第 3 步: 写配置块**(追加到 `~/.dsh/cordis.patch.yml`, 该文件就是顶层 YAML 数组;
已存在就往末尾追加, 先备份):

OpenAI 兼容版(`<GW>` 要带 `/v1`):

```yaml
- id: llm-pi-ai
  config:
    providers:
      intranet-gw:
        displayName: 内网网关
        api: openai-completions
        baseURL: <GW>/v1
        apiKeyEnv: INTRANET_LLM_API_KEY
        compat:
          thinkingFormat: zai          # GLM 系思维链方言; 非 GLM 删掉
          maxTokensField: max_tokens   # 网关不认 max_completion_tokens 时才加
          supportsStore: false         # 网关拒 store 时才加
        defaultContextWindow: 204800
        defaultMaxTokens: 32768
        models:
          - id: glm5.3
            name: glm5.3
            contextWindow: 204800
            maxTokens: 32768
- id: agent-default-model
  config:
    provider: intranet-gw
    model: glm5.3
```

Claude 对接版(`<GW>` 不要带 `/v1`):

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
    baseURL: <GW>
    maxTokens: 32768
    reasoningEffort: off
    models:
      - id: glm5.3
        name: glm5.3
        contextWindow: 204800
- id: agent-default-model
  config:
    provider: deepseek-official
    model: glm5.3
```

> 三个 `disabled` 只在网关拒私有字段时才需要; 但先关掉最省事, 关掉不影响对话能力。

**第 4 步: 校验并冒烟**:

```bash
dsh --profile headless --dump-config | grep -A6 'id: llm-pi-ai'   # 能看到内网路由
dsh --profile headless "只回答两个字：正常"                        # 真跑一次
```

---

## 附录 C: 本机已验证的事实(可作为对照基线)

以下都在这套脚本的开发机上实测过, 内网出现不一致时优先怀疑环境:

- **协议与路径**: OpenAI 兼容走 `{baseURL}/chat/completions` + `Authorization: Bearer`;
  Claude 对接走 `{baseURL}/v1/messages` + `x-api-key` 与 `anthropic-version: 2023-06-01`。
- **凭据解析顺序**: 启动环境 > `$DSH_HOME/.credentials.yaml` > 当前目录 `.env` > `$DSH_HOME/.env`。
- **`.env` 限制**: 不允许 `DSH_`/`XDG_`/`DYLD_` 前缀与 `PATH`/`HOME`/`NODE_*`/`LD_*` 等启动引导变量;
  home 层 `.env` 允许写 `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY`。
- **配置层级**: bundle 层 → profile 层(`$DSH_HOME/profiles/<name>/cordis.patch.yml`)
  → home 层(`$DSH_HOME/cordis.patch.yml`)→ `--patch` 覆盖层。home 层对所有 profile 生效,
  改一次 `dsh headless` 与 `dsh web` 同时生效。
- **`--dump-config` 不是校验**: 它只组装配置树、不加载插件, 查不出 `compat` 放错协议这类错误;
  真正加载才会报 `INVALID_CONFIG`。`configure` 因此会把 `baseURL` 临时指向死地址真启动一次做校验。
- **离线可行**: profile 首次初始化不联网(新 profile 的 `dependencies` 为空、不生成 `node_modules`);
  `node_modules` 整包 496 MB 可压成约 117 MB 的 tar.gz 带走, 解包后 `dsh --version` 正常。
- **两种路由都通**: 在 mock 网关上, OpenAI 兼容与 Claude 对接两条路由的 `selftest` 均为全绿;
  在"严格网关"(400 掉私有字段与各种方言)下同样全绿 —— 配置会自动降级。
