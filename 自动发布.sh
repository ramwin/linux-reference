#!/bin/bash
# linux-reference.ramwin.com 服务器端构建脚本:纯 sphinx 构建,不做 git 操作,没有任何 AI 逻辑。
#
# 由服务器的 /usr/local/bin/docs-autodeploy 在仓库快进到 origin/master 之后调用,
# timer 是 docs-autodeploy@linux-reference.timer(每 5 分钟看一眼有没有新提交)。
# 也可以手动跑,前提是当前 commit 就是要上线的版本。
#
# - Python 依赖只在 requirements.txt 变化时安装,pip 用本地缓存
# - 前端静态依赖(_static/node_modules 里的 mermaid/d3)只在 package.json 或
#   pnpm-lock.yaml 变化时 pnpm install,pnpm 用本地 store 缓存
# - 构建输出到 _build/html.new,成功后再原子替换 _build/html;构建失败线上保持旧版
set -euo pipefail

cd "$(dirname "$0")"

VENV=${DOCS_VENV:-/var/lib/docs-deploy/venv/linux-reference}
STATE_DIR=${DOCS_STATE:-/var/lib/docs-deploy}
PIP_CACHE=${PIP_CACHE_DIR:-$HOME/.cache/pip}
STATIC_STAMP="$STATE_DIR/linux-reference.static.sha"

mkdir -p "$STATE_DIR"

# ── 1. Python 依赖:requirements.txt 变了才装(pip 用本地缓存) ────────────
REQ_SHA=$(sha256sum requirements.txt | cut -d' ' -f1)
if [ ! -x "$VENV/bin/sphinx-build" ] || [ "$(cat "$VENV/.requirements.sha" 2>/dev/null)" != "$REQ_SHA" ]; then
    echo "同步 Python 依赖(requirements.txt 有变化,pip 缓存: $PIP_CACHE)"
    [ -x "$VENV/bin/python" ] || { rm -rf "$VENV"; python3 -m venv "$VENV"; }
    PIP_CACHE_DIR="$PIP_CACHE" "$VENV/bin/pip" install -q --disable-pip-version-check -r requirements.txt
    echo "$REQ_SHA" > "$VENV/.requirements.sha"
fi

# ── 2. 前端静态依赖:mermaid 由浏览器从 _static/node_modules 加载 ─────────
#    package.json / pnpm-lock.yaml 变了(或 node_modules 丢了)才装,
#    走 pnpm 本地 store 缓存,不重复下载。pnpm-lock.yaml 是本地忽略文件
#    (全局 gitignore 里有 pnpm-lock.yaml),服务器上可能不存在,所以按存在与否处理。
STATIC_SHA=$(for f in _static/package.json _static/pnpm-lock.yaml; do
    if [ -f "$f" ]; then sha256sum "$f"; fi
done | sha256sum | cut -d' ' -f1)
if [ ! -d _static/node_modules ] \
    || [ "$(cat "$STATIC_STAMP" 2>/dev/null || true)" != "$STATIC_SHA" ]; then
    NODE_BIN=$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)
    [ -n "${NODE_BIN:-}" ] && export PATH="$NODE_BIN:$PATH"
    if command -v pnpm >/dev/null 2>&1; then
        echo "同步前端静态依赖(_static,pnpm store 缓存)"
        if [ -f _static/pnpm-lock.yaml ]; then
            pnpm_install=(pnpm install --frozen-lockfile --prefer-offline --reporter=append-only)
        else
            pnpm_install=(pnpm install --prefer-offline --reporter=append-only)
        fi
        # CI=true:没有 TTY 时允许 pnpm 重建 node_modules(否则它会中止
        # ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY);依赖仍走本地 store 缓存
        if (cd _static && CI=true "${pnpm_install[@]}"); then
            echo "$STATIC_SHA" > "$STATIC_STAMP"
        else
            echo "警告: pnpm install 失败,继续构建(mermaid 图可能不渲染),下个周期重试" >&2
        fi
    else
        echo "警告: 找不到 node/pnpm,跳过 _static 依赖同步(mermaid 图可能不渲染)" >&2
    fi
fi

# ── 3. 构建:先出临时目录,成功后才替换线上目录 ─────────────────────────
rm -rf _build/html.new
"$VENV/bin/sphinx-build" -q -b html . _build/html.new -d _build/doctrees
rsync -a --delete _build/html.new/ _build/html/
rm -rf _build/html.new

echo "构建完成: _build/html $(du -sh _build/html | cut -f1)"
