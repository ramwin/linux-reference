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
USE_PROXY=0
NO_KEY_FILE=0
MOCK_STRICT=0                 # selftest 专用: 让 mock 扮演严格网关
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
  --insecure           忽略自签证书
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
    check_key_shape
    local emit_dir="${1:-}"
    local args=(--url "$BASE_URL" --key "$API_KEY" --context-window "$CONTEXT_WINDOW"
                --max-tokens "$MAX_TOKENS" --key-var "$KEY_VAR")
    if [ -n "$MODEL" ]; then args+=(--model "$MODEL"); fi
    if [ "$INSECURE" = 1 ]; then args+=(--insecure); fi
    if [ "$USE_PROXY" = 1 ]; then args+=(--use-proxy); fi
    if [ -n "$emit_dir" ]; then args+=(--emit "$emit_dir"); fi
    python3 "$PROBE" "${args[@]}"
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
    out="$(NODE_NO_WARNINGS=1 DSH_HOME="$DSH_HOME_DIR" timeout 120 "${DSH_RUN[@]}" \
            --profile "$PROFILE" --patch "$tmp" "config-check" 2>&1)" || true
    rm -f "$tmp"
    VALIDATE_MSG="$(printf '%s\n' "$out" | grep -m1 INVALID_CONFIG || true)"
    if [ -n "$VALIDATE_MSG" ]; then
        return 1
    fi
    return 0
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
            say "[ok] 插件级校验通过(把 baseURL 临时指向死地址启动一次, 只查 INVALID_CONFIG)"
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
        if ! cmd_smoke; then failed=1; fi
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
    doctor)    cmd_doctor ;;
    selftest)  cmd_selftest ;;
    help|--help|-h) usage ;;
    *) usage; die "未知子命令: $CMD" ;;
esac
