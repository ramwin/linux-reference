#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# dsh-intranet.sh —— 把内网的大模型网关接到 DeepSeek Harness(DSH) 上
#
# 四个子命令, 按顺序用:
#   ./dsh-intranet.sh probe     --url http://10.0.0.9:8000 --key sk-xxx
#   ./dsh-intranet.sh configure --url http://10.0.0.9:8000 --key sk-xxx [--model glm-5.3]
#   ./dsh-intranet.sh smoke
#   ./dsh-intranet.sh selftest              # 不碰真网关, 用本机 mock 自检整条链路
#
# 设计原则:
#   * 只写两个地方 —— $DSH_HOME/cordis.patch.yml(受管块) 和 $DSH_HOME/.env(密钥),
#     其他配置一律不动; 每次写之前都备份。
#   * 网关能接受什么字段, 由 probe 实测决定, 不靠猜。
#   * 所有判断都能在 selftest 里离线复现。

set -euo pipefail

# 内网机器常见 LANG=zh_CN.GBK。那种 locale 下 Python 会把"文件系统编码"也当成
# GBK: ✅/❌ 之类的输出字符编不出去(UnicodeEncodeError), 而且 argv 里的中文
# (比如受管块的起止标记)会被 surrogate-escape 成孤立代理字符, 写文件时再炸一次。
# PYTHONUTF8=1 打开 UTF-8 模式, argv / 文件名 / 标准输出一起归一, 两个坑都堵上;
# PYTHONIOENCODING 只是额外保险。
export PYTHONUTF8="${PYTHONUTF8:-1}"
export PYTHONIOENCODING="${PYTHONIOENCODING:-utf-8}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$HERE/probe_gateway.py"
MOCK="$HERE/mock_gateway.py"

# ---------------------------------------------------------------- 默认值
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PATCH_FILE=""                 # 缺省 = $DSH_HOME_DIR/cordis.patch.yml
PROFILE="headless"
BASE_URL=""
API_KEY=""
MODEL=""
API_CHOICE="auto"             # auto | openai | anthropic
CONTEXT_WINDOW="204800"
MAX_TOKENS="32768"
INSECURE=0
CA_FILE=""                     # 自签 HTTPS 网关的 CA; 会同时喂给探测与 DSH 自己
USE_PROXY=0
NO_KEY_FILE=0
MOCK_STRICT=0                 # selftest 专用: 让 mock 扮演严格网关
MOCK_PORT_BASE="${MOCK_PORT_BASE:-18500}"   # verify 用的端口起点
VERIFY_TMP=""                 # verify 的临时目录(全局, 供 EXIT trap 清理)
VERIFY_PIDS=()                # verify 起的 mock 进程(全局, 同上)
KEY_VAR="INTRANET_LLM_API_KEY"   # 不能以 DSH_/XDG_ 开头: 那类名字 DSH 只认启动环境
TIMEOUT_S="300"
SMOKE_PROMPT="只回答两个字：正常"
BACKUP_TAG="$(date +%Y%m%d-%H%M%S)"
BLOCK_BEGIN="# >>> dsh-intranet managed block (由 dsh-intranet.sh 维护, 手改会被覆盖) >>>"
BLOCK_END="# <<< dsh-intranet managed block <<<"

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
dsh-intranet.sh —— 把内网大模型网关接到 DeepSeek Harness(DSH) 上

  probe       只探测网关: 它能接受哪些字段, 推荐用哪种协议
  configure   探测 + 写 $DSH_HOME/cordis.patch.yml 与 $DSH_HOME/.env + 校验配置
  smoke       真跑一次 dsh, 看模型是否回话
  show        打印当前受管配置块(密钥打码)
  install     安装 DSH(在线用 --registry, 离线用 --bundle)
  bundle      在"有外网的机器"上打包离线安装包
  verify      验收工具箱本身: 13 个用例(协议形态/locale/凭据/边界/自签 HTTPS/profile/文档样例), 不碰真网关
  doctor      体检: 环境 + 配置 + 网关 + 冒烟, 一次跑完(输出整段贴回来最省事)
  selftest    本机起 mock 网关, 走一遍 probe+configure+smoke(不碰真网关)

公共参数:
  --url URL            网关地址, 带不带 /v1 都行
  --key KEY            API Key
  --model ID           模型 id(省略则从 /v1/models 里挑, 优先含 glm 的)
  --api NAME           auto(默认) | openai | anthropic
  --dsh-home DIR       DSH 家目录, 默认 $DSH_HOME 或 ~/.dsh
  --profile NAME       校验/冒烟用的 profile, 默认 headless
  --patch-file FILE    受管块写到哪里, 默认 $DSH_HOME/cordis.patch.yml
  --context-window N   模型上下文窗口, 默认 204800
  --max-tokens N       单次输出上限, 默认 32768(要小于网关允许值)
  --key-var NAME       凭据环境变量名, 默认 INTRANET_LLM_API_KEY
  --no-key-file        不写 .env, 自己 export 那个变量
  --insecure           探测时忽略自签证书(只影响探测, 见 --ca-file)
  --ca-file FILE       自签 HTTPS 网关的 CA 证书: 探测与 DSH 都会信任它(推荐)
  --use-proxy          探测时走 http_proxy/https_proxy(默认绕过)
  --timeout S          冒烟超时, 默认 300
  --prompt TEXT        冒烟用的提示词
  --strict             selftest 专用: 让 mock 扮演严格网关(拒 DeepSeek 私有字段与 OpenAI 方言)
  --registry URL       install 时用的 npm 源
  --prefix DIR         install 时装到这个目录(不需要 root), 例如 --prefix ~/dsh
  --bundle FILE        install 时用离线包
  --out FILE           bundle 的输出路径
  --version VER        install 的 dsh 版本
EOF
}

# ------------------------------------------------------------ 参数解析
CMD="${1:-help}"
shift || true

while [ $# -gt 0 ]; do
    case "$1" in
        --url)            BASE_URL="${2:?}"; shift 2 ;;
        --key)            API_KEY="${2:?}"; shift 2 ;;
        --model)          MODEL="${2:?}"; shift 2 ;;
        --api)            API_CHOICE="${2:?}"; shift 2 ;;
        --dsh-home)       DSH_HOME_DIR="${2:?}"; shift 2 ;;
        --profile)        PROFILE="${2:?}"; shift 2 ;;
        --patch-file)     PATCH_FILE="${2:?}"; shift 2 ;;
        --context-window) CONTEXT_WINDOW="${2:?}"; shift 2 ;;
        --max-tokens)     MAX_TOKENS="${2:?}"; shift 2 ;;
        --key-var)        KEY_VAR="${2:?}"; shift 2 ;;
        --no-key-file)    NO_KEY_FILE=1; shift ;;
        --insecure)       INSECURE=1; shift ;;
        --ca-file)        CA_FILE="${2:?}"; shift 2 ;;
        --use-proxy)      USE_PROXY=1; shift ;;
        --timeout)        TIMEOUT_S="${2:?}"; shift 2 ;;
        --bundle)         BUNDLE="${2:?}"; shift 2 ;;
        --registry)       REGISTRY="${2:?}"; shift 2 ;;
        --prefix)         PREFIX_DIR="${2:?}"; shift 2 ;;
        --out)            OUT="${2:?}"; shift 2 ;;
        --version)        DSH_VERSION="${2:?}"; shift 2 ;;
        --prompt)         SMOKE_PROMPT="${2:?}"; shift 2 ;;
        --strict)         MOCK_STRICT=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *) die "未知参数: $1 (--help 看用法)" ;;
    esac
done

case "$KEY_VAR" in
    DSH_*|XDG_*|DYLD_*) die "--key-var 不能以 DSH_/XDG_/DYLD_ 开头: DSH 只允许启动环境设置这类变量" ;;
esac
[ -n "$PATCH_FILE" ] || PATCH_FILE="$DSH_HOME_DIR/cordis.patch.yml"

# 关键: 探测用的 TLS 设置不会跟着 DSH 进程走 —— DSH 是独立的 Node 进程, 它信不信
# 那张自签证书由 NODE_EXTRA_CA_CERTS 决定。这里统一导出, 两边才一致。
if [ -n "$CA_FILE" ]; then
    [ -f "$CA_FILE" ] || die "--ca-file 指向的 $CA_FILE 不存在"
    export NODE_EXTRA_CA_CERTS="$CA_FILE"
fi

need_python() {
    command -v python3 >/dev/null 2>&1 || die "需要 python3(零依赖, 只用标准库)。装一个, 或看 README 的手工配置法"
}

# --------------------------------------------------------- 定位 dsh 命令
# 全局数组 DSH_RUN; 找不到就返回 1
find_dsh() {
    if command -v dsh >/dev/null 2>&1; then
        DSH_RUN=(dsh); return 0
    fi
    # install --prefix 装到非标准目录时, 这里挂的软链就是唯一的入口
    if [ -x "$HOME/.local/bin/dsh" ]; then
        DSH_RUN=("$HOME/.local/bin/dsh"); return 0
    fi
    local candidate
    for candidate in \
        "$HOME/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js" \
        "$HOME/node_modules/@deepseek-ai/dsh/lib/bin.js" \
        "/usr/lib/node_modules/@deepseek-ai/dsh/lib/bin.js" \
        "/usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
    do
        if [ -f "$candidate" ]; then
            DSH_RUN=(node "$candidate"); return 0
        fi
    done
    return 1
}

node_major() {
    command -v node >/dev/null 2>&1 || return 1
    node -p 'process.versions.node.split(".")[0]' 2>/dev/null
}

# 实测: Node 20 上 dsh 会"退出码 0 + 一个字都不输出"(连请求都不发), Node 22 起正常。
MIN_NODE_MAJOR=22
check_node() {
    local maj; maj="$(node_major || true)"
    if [ -z "$maj" ]; then
        warn "没找到 node —— DSH 是 Node 应用, 得先装 Node"
        return 1
    fi
    if [ "$maj" -lt "$MIN_NODE_MAJOR" ]; then
        warn "node $(node -v) 低于本方案实测可用的下限 v$MIN_NODE_MAJOR:
       Node 20 上 dsh 会静默什么都不做(退出码 0, 无任何输出, 连模型请求都不发)。
       换 Node 22+ 再试, 官方静态包: https://nodejs.org/dist/"
        return 1
    fi
    return 0
}

require_dsh() {
    find_dsh || die "找不到 dsh。先跑 ./dsh-intranet.sh install(--help 看离线安装)"
    check_node || true
}

# ------------------------------------------------------- YAML 受管块写入
apply_block() {
    # $1=目标 yml  $2=内容文件
    python3 - "$1" "$2" "$BLOCK_BEGIN" "$BLOCK_END" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
body = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").rstrip()
begin, end = sys.argv[3], sys.argv[4]
block = f"{begin}\n{body}\n{end}\n"
text = path.read_text(encoding="utf-8") if path.exists() else ""
if begin in text and end in text:
    head, rest = text.split(begin, 1)
    _, tail = rest.split(end, 1)
    text = head + block + tail.lstrip("\n")
else:
    if text.strip():
        text = text.rstrip("\n") + "\n\n" + block
    else:
        text = "# DSH 用户覆盖层(home patch): 对 web / headless 等所有 profile 生效。\n" + block
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text, encoding="utf-8")
print(f"[ok] 已写入受管块: {path}")
PY
}

# ----------------------------------------------------------- .env 写入
apply_key_file() {
    local env_file="$DSH_HOME_DIR/.env"
    if [ -f "$env_file" ]; then
        cp -p "$env_file" "$env_file.bak-$BACKUP_TAG"
        say "[ok] 已备份 $env_file -> $env_file.bak-$BACKUP_TAG"
    fi
    python3 - "$env_file" "$KEY_VAR" "$API_KEY" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]); name = sys.argv[2]; value = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
out, replaced = [], False
for line in lines:
    if line.strip().startswith(name + "="):
        out.append(f"{name}={value}"); replaced = True
    else:
        out.append(line)
if not replaced:
    if not out:
        out = ["# DSH home 级 .env: 只有本用户可以读。这里的变量会进到模型请求的凭据解析里。",
               "# 注意: DSH_ / XDG_ / PATH / NODE_* 这类「启动引导」变量不允许写在 .env 里。"]
    if out and out[-1].strip() == "":
        out[-1] = f"{name}={value}"
    else:
        out.append(f"{name}={value}")
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text("\n".join(out).rstrip("\n") + "\n", encoding="utf-8")
PY
    chmod 600 "$env_file"
    say "[ok] 已写入密钥: $env_file ($KEY_VAR=***)"
}

# 数字参数校验 + 窗口/输出上限的关系。主动压缩(compaction-basic)默认是开着的,
# 窗口留不出发出请求的余量时, 配置能启动、冒烟也可能过, 但在真实对话里迟早撞窗口。
check_numbers() {
    case "$CONTEXT_WINDOW" in ''|*[!0-9]*) die "--context-window 必须是正整数(收到: $CONTEXT_WINDOW)" ;; esac
    case "$MAX_TOKENS" in ''|*[!0-9]*) die "--max-tokens 必须是正整数(收到: $MAX_TOKENS)" ;; esac
    if [ "$MAX_TOKENS" -ge "$CONTEXT_WINDOW" ]; then
        die "--max-tokens $MAX_TOKENS 不小于 --context-window $CONTEXT_WINDOW: 窗口连一次输出都装不下。
     典型配法: --context-window 204800 --max-tokens 32768"
    fi
    if [ "$CONTEXT_WINDOW" -lt $((MAX_TOKENS * 2)) ]; then
        warn "上下文窗口 $CONTEXT_WINDOW 不到输出上限 $MAX_TOKENS 的两倍, 主动压缩会频繁触发; 确认这是有意的"
    fi
}

check_key_shape() {
    case "$API_KEY" in
        *[!A-Za-z0-9._:-]*) warn "key 里有非 [A-Za-z0-9._:-] 的字符, .env 解析可能出问题; 建议改用 --no-key-file 自己 export" ;;
    esac
    [ -n "$API_KEY" ] || die "缺少 --key"
    [ -n "$BASE_URL" ] || die "缺少 --url"
}

# ------------------------------------------------------------- probe
run_probe() {
    need_python
    check_numbers
    check_key_shape
    local emit_dir="${1:-}"
    local args=(--url "$BASE_URL" --key "$API_KEY" --context-window "$CONTEXT_WINDOW"
                --max-tokens "$MAX_TOKENS" --key-var "$KEY_VAR")
    if [ -n "$MODEL" ]; then args+=(--model "$MODEL"); fi
    if [ "$INSECURE" = 1 ]; then args+=(--insecure); fi
    if [ -n "$CA_FILE" ]; then args+=(--ca-file "$CA_FILE"); fi
    if [ "$USE_PROXY" = 1 ]; then args+=(--use-proxy); fi
    if [ -n "$emit_dir" ]; then args+=(--emit "$emit_dir"); fi
    python3 "$PROBE" "${args[@]}"
}

# 只有 https 才检查证书: 0=可信或不是 https, 1=证书不被信任
tls_trust_check() {
    case "$1" in https://*) ;; *) return 0 ;; esac
    python3 - "$1" "${CA_FILE:-}" <<'PY'
import socket, ssl, sys, urllib.parse

url, ca_file = sys.argv[1], sys.argv[2]
parts = urllib.parse.urlsplit(url)
host, port = parts.hostname or "", parts.port or 443
ctx = ssl.create_default_context()
if ca_file:
    try:
        ctx.load_verify_locations(cafile=ca_file)
    except Exception:
        pass
try:
    with socket.create_connection((host, port), timeout=6) as sock:
        with ctx.wrap_socket(sock, server_hostname=host):
            pass
except ssl.SSLCertVerificationError:
    sys.exit(1)
except Exception:
    sys.exit(0)  # 连不上之类的问题不在这里下结论
sys.exit(0)
PY
}

# --------------------------------------------------------- configure
PATCH_CHOSEN=""
pick_patch() {
    local dir="$1"
    local wanted="$API_CHOICE"
    if [ "$wanted" = auto ]; then
        if [ -f "$dir/cordis.patch.openai.yml" ]; then wanted=openai
        elif [ -f "$dir/cordis.patch.anthropic.yml" ]; then wanted=anthropic
        else die "网关两种协议都没打通, 先看 probe 输出"; fi
    fi
    PATCH_CHOSEN="$dir/cordis.patch.$wanted.yml"
    [ -f "$PATCH_CHOSEN" ] || die "网关不支持 $wanted 协议(或探测失败), 换 --api 或先看 probe 输出"
    say "[ok] 选用 $wanted 路由"
}

# --dump-config 只组装配置树, 不加载插件, 因此查不出 "compat 开关放错协议" 这类
# 运行期校验错误; 这里用一份"只把 baseURL 换成死地址"的副本真启动一次:
#   * 配置本身有问题 -> INVALID_CONFIG(在任何网络 I/O 之前抛出)
#   * 配置没问题     -> TRANSPORT(连不上 127.0.0.1:1), 这是我们想要的
# 代价是一次本地连接失败, 不碰真网关、不发模型请求。
VALIDATE_MSG=""
validate_config_offline() {
    local src="$1" tmp out
    VALIDATE_MSG=""
    tmp="$(mktemp)"
    sed -E 's#^([[:space:]]*baseURL:).*#\1 http://127.0.0.1:1/v1#' "$src" > "$tmp"
    if ! grep -q 'baseURL:' "$tmp"; then rm -f "$tmp"; return 0; fi
    # 固定用 headless 做这次启动: 它"跑一句就退出", 而 web/acp/sdk 会常驻, 既拿不到
    # 结论、还可能占住端口。配置在 home 层, 对所有 profile 是同一份, 校验等价。
    out="$(NODE_NO_WARNINGS=1 DSH_HOME="$DSH_HOME_DIR" timeout 120 "${DSH_RUN[@]}" \
            --profile headless --patch "$tmp" "config-check" 2>&1)" || true
    rm -f "$tmp"
    case "$out" in
        *INVALID_CONFIG*)
            VALIDATE_MSG="$(printf '%s\n' "$out" | grep -m1 INVALID_CONFIG)"
            return 1
            ;;
        # 走到"连不上死地址"或"凭据缺失"这一步, 就说明插件已经加载成功了
        *TRANSPORT*|*MISSING_CREDENTIAL*|*INVALID_CREDENTIAL*|*AUTH*|*RATE_LIMIT*|*QUOTA*|*HTTP_*)
            return 0
            ;;
        # 既不是配置错误, 也不是预期的连接失败 —— 说明这次校验根本没真正跑起来。
        # 曾经出现过: --profile web 启动报 "too many arguments", 却被当成"校验通过"。
        *)
            VALIDATE_MSG="校验没能真正跑起来(输出既不是 INVALID_CONFIG, 也不是预期的连接失败): $(printf '%s\n' "$out" | tail -1)"
            return 1
            ;;
    esac
}

cmd_probe() { run_probe; }

cmd_configure() {
    need_python
    require_dsh
    step "1/4 探测网关"
    local tmp; tmp="$(mktemp -d)"
    run_probe "$tmp/patches"

    step "2/4 选择路由"
    pick_patch "$tmp/patches"

    step "3/4 写入配置"
    if [ -f "$PATCH_FILE" ]; then
        cp -p "$PATCH_FILE" "$PATCH_FILE.bak-$BACKUP_TAG"
        say "[ok] 已备份 $PATCH_FILE -> $PATCH_FILE.bak-$BACKUP_TAG"
    fi
    # 防御: 配置里引用的凭据名必须和我们写进 .env 的名字一致, 否则冒烟才会以
    # MISSING_CREDENTIAL 暴露出来。这里当场拦住。
    if ! grep -q "apiKeyEnv: $KEY_VAR" "$PATCH_CHOSEN"; then
        die "生成的配置里没有 apiKeyEnv: $KEY_VAR(生成的凭据名与 --key-var 不一致), 已中止, 未写入 $PATCH_FILE"
    fi
    apply_block "$PATCH_FILE" "$PATCH_CHOSEN"
    if [ "$NO_KEY_FILE" = 1 ]; then
        say "[--] 按 --no-key-file 跳过 .env; 请自行 export $KEY_VAR=..."
    else
        apply_key_file
    fi

    step "4/4 校验配置"
    local dumped ok_config=1
    if dumped="$(NODE_NO_WARNINGS=1 DSH_HOME="$DSH_HOME_DIR" "${DSH_RUN[@]}" --profile "$PROFILE" --dump-config 2>&1)"; then
        if printf '%s' "$dumped" | grep -q "intranet-gw\|llm-deepseek"; then
            say "[ok] 配置树组装成功, 路由已注册"
        else
            warn "配置能组装, 但没看到内网路由; 检查 $PATCH_FILE"
        fi
    else
        ok_config=0
    fi
    if [ "$ok_config" = 1 ]; then
        if validate_config_offline "$PATCH_CHOSEN"; then
            say "[ok] 插件级校验通过(死地址启动一次: 没有 INVALID_CONFIG, 也确实走到了发请求那一步)"
        else
            ok_config=0
        fi
    fi
    if [ "$ok_config" = 0 ]; then
        if [ -n "$VALIDATE_MSG" ]; then
            printf '%s\n' "$VALIDATE_MSG" >&2
        else
            printf '%s\n' "$dumped" | tail -20
        fi
        if [ -f "$PATCH_FILE.bak-$BACKUP_TAG" ]; then
            cp -p "$PATCH_FILE.bak-$BACKUP_TAG" "$PATCH_FILE"
            warn "配置校验失败, 已回滚 $PATCH_FILE"
        else
            rm -f "$PATCH_FILE"
            warn "配置校验失败, 已删除新写的 $PATCH_FILE"
        fi
        die "配置校验失败(上面是 DSH 的报错)"
    fi

    rm -rf "$tmp"
    step "下一步"
    say "  ./dsh-intranet.sh smoke            # 真跑一次"
    say "  dsh web                            # 起 Web GUI(如果内网装了 web profile)"
}

cmd_smoke() {
    require_dsh
    if [ "$PROFILE" != "headless" ]; then
        die "smoke 只能在 headless profile 上跑(收到 --profile $PROFILE)。
      web / acp / sdk 这些 profile 不会因为一句任务就退出, 拿不到冒烟结论。
      GUI 的人工自检: dsh web --no-open, 打开它打印的带 token 地址,
      在模型选择器里选「内网网关 / <模型 id>」再发一句"你好"。"
    fi
    step "冒烟: dsh --profile $PROFILE \"$SMOKE_PROMPT\""
    local out status=0
    out="$(DSH_HOME="$DSH_HOME_DIR" timeout "$TIMEOUT_S" "${DSH_RUN[@]}" \
            --profile "$PROFILE" "$SMOKE_PROMPT" 2>&1)" || status=$?
    printf '%s\n' "$out"
    echo "----------------------------------------------------------------"
    if [ "$status" -eq 0 ] && [ -n "$out" ]; then
        say "✅ 模型回话了, 内网 DSH 接通。"
        return 0
    fi
    warn "退出码 $status"
    if [ "$status" -eq 0 ] && [ -z "$out" ]; then
        say "→ 退出码 0 却一个字都没输出: 头号嫌疑是 node 版本过低(实测 Node 20 就是这种静默)。"
        say "  先跑 dsh --version, 同样空的话换 Node $MIN_NODE_MAJOR+ 再试。"
    fi
    # DSH 把证书问题也报成 "TRANSPORT: Connection error.", 不主动查一下就会
    # 让人去怀疑防火墙/端口。这里先自己验一次证书。
    local cbase
    cbase="$(grep -m1 -oE 'baseURL: *[^ ]+' "$PATCH_FILE" 2>/dev/null | awk '{print $2}')"
    if [ -n "$cbase" ] && ! tls_trust_check "$cbase"; then
        say "→ 网关的 HTTPS 证书不被信任(DSH 只会说 Connection error, 不会告诉你这个)"
        say "  探测用的 --insecure 不会传给 DSH: DSH 是独立的 Node 进程。这样修:"
        say "    ./dsh-intranet.sh smoke --ca-file /path/to/ca.pem     # 只多信这一张证书(推荐)"
        say "    export NODE_EXTRA_CA_CERTS=/path/to/ca.pem            # 或永久加到 ~/.bashrc"
        say "    export NODE_TLS_REJECT_UNAUTHORIZED=0                 # 实在没有 CA 时的下策"
    fi
    case "$out" in
        *MISSING_CREDENTIAL*)
            local want; want="$(grep -m1 -oE 'apiKeyEnv: *[A-Za-z_][A-Za-z0-9_]*' "$PATCH_FILE" 2>/dev/null | awk '{print $2}')"
            say "→ 没拿到 key: 配置里 apiKeyEnv 指定的是 ${want:-$KEY_VAR}, 但 $DSH_HOME_DIR/.env 和启动环境里都没有它"
            say "  (用了 --no-key-file 的话, 就得自己在启动 DSH 前 export)" ;;
        *INVALID_CREDENTIAL*) say "→ key 格式不对(被网关/DSH 拒绝)" ;;
        *AUTH*|*401*|*403*)   say "→ 鉴权失败: key 不对, 或网关需要别的头" ;;
        *404*|*"not found"*)  say "→ 路径不对: 多半是 baseURL 少了/多了 /v1, 重跑 probe 看它报的可用路径" ;;
        *400*)                say "→ 网关拒了某个字段: 重跑 probe, 把它标记 false 的 compat 开关写进配置" ;;
        *TRANSPORT*|*Connection*|*ECONNREFUSED*|*TIMEOUT*)
            say "→ 连不上网关: 地址/端口/防火墙; 需要走代理就 export HTTPS_PROXY" ;;
    esac
    return 1
}

cmd_show() {
    say "DSH_HOME   : $DSH_HOME_DIR"
    say "受管配置块 : $PATCH_FILE"
    if [ -f "$PATCH_FILE" ] && grep -qF "$BLOCK_BEGIN" "$PATCH_FILE"; then
        awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '$0==b{f=1} f{print} $0==e{f=0}' "$PATCH_FILE"
    else
        warn "还没有受管块(先跑 configure)"
    fi
    local env_file="$DSH_HOME_DIR/.env"
    if [ -f "$env_file" ]; then
        say ""
        say "密钥文件   : $env_file"
        # 掩掉"每一行赋值", 而不是只掩 $KEY_VAR: 否则用 --key-var 换了变量名时,
        # 这里会把密钥原样打出来(而这份输出是要贴进报告里的)。
        sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1=***/' "$env_file" | sed 's/^/    /'
    else
        warn "没有 $env_file(可能用了 --no-key-file)"
    fi
    if find_dsh; then
        say ""
        say "dsh 命令   : ${DSH_RUN[*]}"
    fi
}

# ------------------------------------------------------------ install
cmd_install() {
    if [ -n "${BUNDLE:-}" ]; then
        cmd_unpack
        return
    fi
    command -v npm >/dev/null 2>&1 || die "没有 npm。离线部署请用 ./dsh-intranet.sh bundle 打包后 --bundle 安装"
    local ver="${DSH_VERSION:-latest}"
    local registry_args=()
    if [ -n "${REGISTRY:-}" ]; then registry_args=(--registry "$REGISTRY"); fi

    if [ -n "${PREFIX_DIR:-}" ]; then
        # 非 root 机器的正路: 装进自己的目录, find_dsh 认得 $HOME/dsh, 其他前缀挂个软链
        step "npm 本地安装 @deepseek-ai/dsh@$ver -> $PREFIX_DIR(不需要 root)"
        mkdir -p "$PREFIX_DIR"
        if ! npm install --prefix "$PREFIX_DIR" --no-audit --no-fund \
                "${registry_args[@]}" "@deepseek-ai/dsh@$ver"; then
            warn "npm 安装失败。内网常见原因: 没有内网 npm 源(加 --registry)、需要代理、或包名/版本不对"
            die "安装失败, 见上面 npm 的输出"
        fi
        local bin="$PREFIX_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"
        [ -f "$bin" ] || die "装完了但找不到 $bin"
        mkdir -p "$HOME/.local/bin"
        ln -sf "$bin" "$HOME/.local/bin/dsh"
        chmod +x "$bin" 2>/dev/null || true
        say "[ok] 已装到 $PREFIX_DIR, 并软链到 $HOME/.local/bin/dsh"
        say "     把 export PATH=\"\$HOME/.local/bin:\$PATH\" 加进 ~/.bashrc 就能直接敲 dsh"
        find_dsh || true
        return 0
    fi

    step "npm 全局安装 @deepseek-ai/dsh@$ver(需要写全局目录的权限; 没权限就加 --prefix ~/dsh)"
    if ! npm install -g "${registry_args[@]}" "@deepseek-ai/dsh@$ver"; then
        warn "全局安装失败。没有 root/写权限时改用: ./dsh-intranet.sh install --prefix ~/dsh"
        die "安装失败, 见上面 npm 的输出"
    fi
    find_dsh || die "装完了还是找不到 dsh, 看 npm prefix -g 是否在 PATH 里"
    say "[ok] ${DSH_RUN[*]}"
}

cmd_unpack() {
    [ -n "${BUNDLE:-}" ] || die "缺少 --bundle 包路径"
    [ -f "$BUNDLE" ] || die "找不到 $BUNDLE"
    local target="${DSH_INSTALL_DIR:-$HOME/dsh}"
    step "解包 $BUNDLE -> $target"
    mkdir -p "$target"
    tar -xzf "$BUNDLE" -C "$target"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$target/node_modules/@deepseek-ai/dsh/lib/bin.js" "$HOME/.local/bin/dsh"
    chmod +x "$target/node_modules/@deepseek-ai/dsh/lib/bin.js" 2>/dev/null || true
    say "[ok] 装好了。把 export PATH=\"\$HOME/.local/bin:\$PATH\" 加进 ~/.bashrc, 然后 dsh --version"
}

cmd_bundle() {
    local out="${OUT:-$PWD/dsh-offline-$(date +%Y%m%d).tar.gz}"
    local src="${DSH_INSTALL_DIR:-$HOME}"
    [ -d "$src/node_modules/@deepseek-ai/dsh" ] || die "$src/node_modules 里没有 @deepseek-ai/dsh"
    step "打包 $src/node_modules -> $out (几百 MB, 耐心等)"
    tar -czf "$out" -C "$src" node_modules package.json 2>/dev/null || \
        tar -czf "$out" -C "$src" node_modules
    say "[ok] $out  ($(du -h "$out" | cut -f1))"
    say "目标机器上: ./dsh-intranet.sh install --bundle $out"
    warn "离线包与 CPU 架构/glibc 绑定(这里是 $(uname -m)); 目标机同架构才能直接用"
}

# ----------------------------------------------------------- verify
# 把"本机验证过的形态"固化成一条可重复执行的验收命令。用几个 mock 分别扮演
# 不同的网关(each on its own port), 逐项跑完打印 ✅/❌ 矩阵。
cmd_verify() {
    need_python
    require_dsh
    VERIFY_TMP="$(mktemp -d)"; local tmp="$VERIFY_TMP"
    local base=$((MOCK_PORT_BASE))
    local p_plain="$((base))" p_strict="$((base + 1))" p_openai="$((base + 2))"
    local p_anth="$((base + 3))" p_tls="$((base + 4))"
    VERIFY_PIDS=()
    start_mock() {  # $1=port $2=log 其余=额外参数
        local port="$1" log="$2"; shift 2
        nohup python3 "$MOCK" --port "$port" --model "glm-5.3" --log "$log" "$@"             >"$tmp/mock-$port.log" 2>&1 &
        VERIFY_PIDS+=("$!")
    }
    start_mock "$p_plain"  "$tmp/plain.jsonl"
    start_mock "$p_strict" "$tmp/strict.jsonl" --strict
    start_mock "$p_openai" "$tmp/openai.jsonl" --only openai
    start_mock "$p_anth"   "$tmp/anth.jsonl"   --only anthropic
    # 变量都是全局的: EXIT trap 在函数返回后才跑, 那时 local 已经看不到了
    trap '[ ${#VERIFY_PIDS[@]} -gt 0 ] && for p in "${VERIFY_PIDS[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$VERIFY_TMP"' EXIT
    sleep 1.5

    local pass=0 fail=0
    ok()   { printf '  \033[1;32m✅ %s\033[0m\n' "$1"; pass=$((pass + 1)); }
    bad()  { printf '  \033[1;31m❌ %s\033[0m\n' "$1"; fail=$((fail + 1));
             [ -n "${2:-}" ] && tail -6 "$2" | sed 's/^/       /' || true; }

    # 每个用例都在自己的 DSH_HOME 里, 互不干扰
    fresh() { DSH_HOME_DIR="$tmp/home-$1"; PATCH_FILE="$DSH_HOME_DIR/cordis.patch.yml"
              rm -rf "$DSH_HOME_DIR"; mkdir -p "$DSH_HOME_DIR"; export DSH_HOME="$DSH_HOME_DIR"; }

    step "1/13 selftest: 本机两种路由(宽松网关)"
    if API_CHOICE=auto MOCK_STRICT=0 ./"$(basename "${BASH_SOURCE[0]}")" selftest >"$tmp/c1" 2>&1
    then ok "selftest 通过"; else bad "selftest 失败" "$tmp/c1"; fi

    step "2/13 selftest: 严格网关(拒私有字段与方言)"
    if MOCK_STRICT=1 ./"$(basename "${BASH_SOURCE[0]}")" selftest >"$tmp/c2" 2>&1
    then ok "严格网关下降级仍然可用"; else bad "严格网关用例失败" "$tmp/c2"; fi

    step "3/13 selftest: 非 UTF-8 locale(zh_CN.GBK)"
    if env LANG=zh_CN.GBK LC_ALL=zh_CN.GBK ./"$(basename "${BASH_SOURCE[0]}")" selftest >"$tmp/c3" 2>&1
    then ok "GBK locale 下不崩"; else bad "GBK locale 用例失败" "$tmp/c3"; fi

    step "4/13 只开 OpenAI 的网关"
    fresh openai
    if BASE_URL="http://127.0.0.1:$p_openai" API_KEY=k API_CHOICE=auto cmd_configure >"$tmp/c4" 2>&1 \
       && cmd_smoke >"$tmp/c4s" 2>&1 && grep -q "llm-pi-ai" "$PATCH_FILE"
    then ok "configure + smoke 通过, 路由为 llm-pi-ai"
    else bad "只开 OpenAI 的用例失败" "$tmp/c4"; fi

    step "5/13 只开 Claude 的网关"
    fresh anth
    if BASE_URL="http://127.0.0.1:$p_anth" API_KEY=k API_CHOICE=auto cmd_configure >"$tmp/c5" 2>&1 \
       && cmd_smoke >"$tmp/c5s" 2>&1 && grep -q "llm-deepseek" "$PATCH_FILE"
    then ok "configure + smoke 通过, 路由为 llm-deepseek"
    else bad "只开 Claude 的用例失败" "$tmp/c5"; fi

    step "6/13 强制网关不支持的协议(应拒绝且不写文件)"
    fresh wrongproto
    if ( BASE_URL="http://127.0.0.1:$p_anth" API_KEY=k API_CHOICE=openai cmd_configure ) >"$tmp/c6" 2>&1
    then bad "本该失败却成功了"
    elif [ -f "$PATCH_FILE" ]; then bad "失败了但留下了半成品 $PATCH_FILE"
    else ok "写文件前干净退出"; fi

    step "7/13 --key-var 自定义凭据名"
    fresh keyvar
    KEY_VAR="VERIFY_CUSTOM_KEY"
    if BASE_URL="http://127.0.0.1:$p_plain" API_KEY=k API_CHOICE=auto cmd_configure >"$tmp/c7" 2>&1 \
       && grep -q "apiKeyEnv: VERIFY_CUSTOM_KEY" "$PATCH_FILE" && cmd_smoke >"$tmp/c7s" 2>&1
    then ok "配置与 .env 用同一个变量名"; else bad "--key-var 用例失败" "$tmp/c7"; fi
    KEY_VAR="INTRANET_LLM_API_KEY"

    step "8/13 --no-key-file(凭据只从启动环境来)"
    fresh nokeyfile
    if NO_KEY_FILE=1 BASE_URL="http://127.0.0.1:$p_plain" API_KEY=env-only-key API_CHOICE=auto \
         cmd_configure >"$tmp/c8" 2>&1 && [ ! -f "$DSH_HOME_DIR/.env" ] \
       && INTRANET_LLM_API_KEY=env-only-key cmd_smoke >"$tmp/c8s" 2>&1
    then ok "没写 .env, 靠启动环境跑通"; else bad "--no-key-file 用例失败" "$tmp/c8"; fi
    NO_KEY_FILE=0

    step "9/13 用户 home patch 里已有无关配置"
    fresh coexist
    printf -- '- id: ui-settings-general\n  config:\n    welcomeNoticeVersion: keep-me\n' > "$PATCH_FILE"
    if BASE_URL="http://127.0.0.1:$p_plain" API_KEY=k API_CHOICE=auto cmd_configure >"$tmp/c9" 2>&1 \
       && grep -q "keep-me" "$PATCH_FILE" && cmd_smoke >"$tmp/c9s" 2>&1
    then ok "原条目保留, 且两者共存可跑"; else bad "共存用例失败" "$tmp/c9"; fi

    step "10/13 窗口小于输出上限(应拒绝)"
    fresh badmath
    if ( BASE_URL="http://127.0.0.1:$p_plain" API_KEY=k CONTEXT_WINDOW=8000 MAX_TOKENS=32768 \
         cmd_configure ) >"$tmp/c10" 2>&1
    then bad "本该拒绝却成功了"
    else ok "拒绝不合理组合"; fi
    CONTEXT_WINDOW=204800; MAX_TOKENS=32768

    step "11/13 自签 HTTPS 网关(探测与 DSH 是两套 TLS, --ca-file 要同时喂到)"
    if command -v openssl >/dev/null 2>&1; then
        if openssl req -x509 -newkey rsa:2048 -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
                -days 2 -nodes -subj "/CN=127.0.0.1" \
                -addext "subjectAltName=IP:127.0.0.1" >"$tmp/openssl.log" 2>&1; then
            start_mock "$p_tls" "$tmp/tls.jsonl" --cert "$tmp/cert.pem" --key "$tmp/key.pem"
            sleep 1
            fresh tls
            # 顶层的 NODE_EXTRA_CA_CERTS 导出只在启动时做一次, 这里改了 CA_FILE
            # 必须跟着重导, 否则 DSH 那一侧还是不信这张证书
            CA_FILE="$tmp/cert.pem"; export NODE_EXTRA_CA_CERTS="$CA_FILE"
            if BASE_URL="https://127.0.0.1:$p_tls" API_KEY=k API_CHOICE=auto cmd_configure >"$tmp/c11" 2>&1 \
               && cmd_smoke >"$tmp/c11s" 2>&1
            then ok "自签 HTTPS: --ca-file 同时喂给了探测与 DSH"
            else bad "自签 HTTPS 用例失败" "$tmp/c11s"; fi
            CA_FILE=""; unset NODE_EXTRA_CA_CERTS
        else
            say "  (openssl 生成证书失败, 跳过)"
        fi
    else
        say "  (没有 openssl, 跳过自签 HTTPS 用例)"
    fi

    step "12/13 非 headless profile 的冒烟要当场拒绝(不能挂住)"
    fresh prof
    if BASE_URL="http://127.0.0.1:$p_plain" API_KEY=k API_CHOICE=auto cmd_configure >"$tmp/c12" 2>&1 \
       && timeout 60 ./"$(basename "${BASH_SOURCE[0]}")" smoke --profile web --dsh-home "$DSH_HOME_DIR" \
            >"$tmp/c12s" 2>&1
    then bad "本该拒绝却成功了"
    elif grep -q "只能在 headless" "$tmp/c12s"; then ok "明确拒绝并给出 GUI 自检指引"
    else bad "拒绝了但没说清原因" "$tmp/c12s"; fi

    step "13/13 任务书附录 B 里手写的 YAML 能否原样使用"
    if python3 "$HERE/check_doc_examples.py" "$HERE/AGENT-TASK.md" \
            "http://127.0.0.1:$p_plain" "$tmp/doccheck" "${DSH_RUN[@]}" >"$tmp/c13" 2>&1
    then ok "文档里的兜底配置可用(改了生成器没改文档就会被这条抓住)"
    else bad "文档里的 YAML 已失效" "$tmp/c13"; fi

    echo
    say "======= verify 结果: $pass 通过, $fail 失败 ======="
    [ "$fail" = 0 ] || die "验收未全绿, 上面 ❌ 的项就是问题所在"
    say "✅ 工具箱本身验收全绿(这些都不需要真网关)。"
}

# ----------------------------------------------------------- doctor
# 一条命令收集"内网这台机器上, DSH 到底行不行"的全部事实, 方便整段贴回来。
cmd_doctor() {
    local failed=0

    step "1/4 运行环境"
    say "  系统        : $(uname -srm)"
    say "  发行版      : $( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo '(没有 /etc/os-release)')"
    local nmaj; nmaj="$(node_major || true)"
    if [ -z "$nmaj" ]; then
        say "  node        : 缺失 ❌ (DSH 跑不起来)"; failed=1
    elif [ "$nmaj" -lt "$MIN_NODE_MAJOR" ]; then
        say "  node        : $(node -v)  ❌ 低于 v$MIN_NODE_MAJOR —— 实测这个版本上 dsh 静默无输出"
        failed=1
    else
        say "  node        : $(node -v)  ✅"
    fi
    if command -v python3 >/dev/null 2>&1; then
        say "  python3     : $(python3 -V 2>&1)"
    else
        say "  python3     : 缺失 ❌ (probe/configure 用不了, 见 README 手工配置法)"; failed=1
    fi
    if command -v npm >/dev/null 2>&1; then say "  npm         : $(npm -v)"; else say "  npm         : 缺失"; fi
    if find_dsh; then
        local ver; ver="$(NODE_NO_WARNINGS=1 DSH_HOME="$DSH_HOME_DIR" "${DSH_RUN[@]}" --version 2>&1 | tail -1)"
        say "  dsh         : ${DSH_RUN[*]}  (版本 $ver)"
    else
        say "  dsh         : 没找到 ❌ 先跑 install"; failed=1
    fi

    step "2/4 配置与凭据"
    say "  DSH_HOME    : $DSH_HOME_DIR"
    if [ -f "$PATCH_FILE" ]; then
        if grep -qF "$BLOCK_BEGIN" "$PATCH_FILE"; then
            say "  受管配置块  : $PATCH_FILE  ✅ 已写入"
        else
            say "  受管配置块  : $PATCH_FILE  存在但没有我们的块(还没 configure?)"; failed=1
        fi
    else
        say "  受管配置块  : $PATCH_FILE  不存在 ❌ 还没 configure"; failed=1
    fi
    # 配置要哪个凭据名, 就读配置里的, 而不是命令行默认值
    local want_key="$KEY_VAR"
    if [ -f "$PATCH_FILE" ]; then
        local from_config
        from_config="$(grep -m1 -oE 'apiKeyEnv: *[A-Za-z_][A-Za-z0-9_]*' "$PATCH_FILE" | awk '{print $2}')"
        if [ -n "$from_config" ]; then want_key="$from_config"; fi
    fi
    local env_file="$DSH_HOME_DIR/.env"
    if [ -f "$env_file" ]; then
        say "  密钥文件    : $env_file (权限 $(stat -c '%a' "$env_file" 2>/dev/null || echo '?'))"
        local names
        names="$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$env_file" | tr -d '=' | paste -sd', ' -)"
        say "  文件里的变量: ${names:-(没有任何赋值)}"
        if grep -q "^${want_key}=" "$env_file"; then
            say "  $want_key : ✅ 在 .env 里"
        elif [ -n "${!want_key:-}" ]; then
            say "  $want_key : ✅ 在启动环境里"
        else
            say "  $want_key : ❌ 配置要这个变量, 但 .env 与启动环境里都没有"; failed=1
        fi
    elif [ -n "${!want_key:-}" ]; then
        say "  密钥文件    : 没有, 但启动环境里已有 $want_key ✅"
    else
        say "  密钥文件    : 没有 ❌ 也没 export $want_key (配置里 apiKeyEnv 指定的名字)"; failed=1
    fi

    step "3/4 网关"
    if [ -n "$BASE_URL" ]; then
        local pdir; pdir="$(mktemp -d)"
        if run_probe "$pdir"; then
            say ""
        else
            say "  探测失败 ❌ (看上面的 HTTP 状态)"; failed=1
        fi
        rm -rf "$pdir"
    else
        say "  (没给 --url, 跳过; 加上 --url 与 --key 一起跑)"
    fi

    step "4/4 冒烟"
    if [ -f "$PATCH_FILE" ] && grep -qF "$BLOCK_BEGIN" "$PATCH_FILE"; then
        if [ "$PROFILE" = "headless" ]; then
            if ! cmd_smoke; then failed=1; fi
        else
            say "  (--profile $PROFILE 不是 headless, 冒烟跳过; web 请按 README 做人工自检)"
        fi
    else
        say "  (受管配置块还没写, 先跑 configure; 冒烟跳过)"
    fi

    echo
    if [ "$failed" = 0 ]; then
        say "✅ doctor 全绿: 这台机器上 DSH + 内网网关已经能用。"
    else
        warn "doctor 有项目没过(上面带 ❌ 的行)。把这份输出整段贴回来说一声就行。"
    fi
    return 0
}

# ----------------------------------------------------------- selftest
cmd_selftest() {
    need_python
    local tmp; tmp="$(mktemp -d)"
    local port="${MOCK_PORT:-18099}"
    if [ "$MOCK_STRICT" = 1 ]; then
        step "selftest(严格网关): 本机 mock 拒掉私有字段与方言 + 隔离 DSH_HOME ($tmp)"
    else
        step "selftest(宽松网关): 本机 mock + 隔离 DSH_HOME ($tmp)"
    fi
    local mock_args=(--port "$port" --model "${MODEL:-glm-5.3}" --log "$tmp/requests.jsonl")
    if [ "$MOCK_STRICT" = 1 ]; then mock_args+=(--strict); fi
    python3 "$MOCK" "${mock_args[@]}" >"$tmp/mock.log" 2>&1 &
    local mock_pid=$!
    trap "kill $mock_pid 2>/dev/null || true; rm -rf '$tmp'" EXIT
    sleep 1
    BASE_URL="http://127.0.0.1:$port"
    API_KEY="selftest-key"
    MODEL="${MODEL:-glm-5.3}"

    # 两种路由各验证一遍, 各自写进隔离的 DSH_HOME
    local api
    for api in openai anthropic; do
        step "### $api 路由"
        API_CHOICE="$api"
        DSH_HOME_DIR="$tmp/home-$api"
        PATCH_FILE="$DSH_HOME_DIR/cordis.patch.yml"
        export DSH_HOME="$DSH_HOME_DIR"
        mkdir -p "$DSH_HOME_DIR"
        cmd_configure
        cmd_smoke
    done

    step "网关侧看到的请求"
    python3 "$HERE/summarize_requests.py" "$tmp/requests.jsonl"
    say ""
    say "✅ selftest 通过: 配置生成 -> 凭据解析 -> 协议转换 -> 模型回话, 两种路由全通。"
}

case "$CMD" in
    probe)     cmd_probe ;;
    configure) cmd_configure ;;
    smoke)     cmd_smoke ;;
    show)      cmd_show ;;
    install)   cmd_install ;;
    bundle)    cmd_bundle ;;
    verify)    cmd_verify ;;
    doctor)    cmd_doctor ;;
    selftest)  cmd_selftest ;;
    help|--help|-h) usage ;;
    *) usage; die "未知子命令: $CMD" ;;
esac
