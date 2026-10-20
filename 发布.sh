#!/usr/bin/env bash
# Xiang Wang(ramwin@qq.com)
#
# 发布 linux-reference 文档到 https://linux-reference.ramwin.com
#
# 站点托管在阿里云 ramwin 上, nginx 直接输出静态文件:
#   /etc/nginx/sites-enabled/linux-reference.ramwin.com
#   root /var/www/github/linux-reference/_build/html
#
# 流程: 检查工作区已提交并推送 -> 服务器 ll 拉取 -> 服务器构建到临时目录 ->
#       rsync 覆盖线上目录 -> curl 校验。构建失败不影响线上内容。
#
# 用法: ./发布.sh [要校验的页面路径, 默认 ai/]
#   DOCS_SERVER / DOCS_REMOTE_DIR / DOCS_BASE_URL 可覆盖默认值
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

SERVER="${DOCS_SERVER:-ramwin}"
REMOTE_DIR="${DOCS_REMOTE_DIR:-/var/www/github/linux-reference}"
BASE_URL="${DOCS_BASE_URL:-https://linux-reference.ramwin.com}"
PAGE="${1:-ai/}"

die() { echo "error: $*" >&2; exit 1; }

# 1. 线上只发布 origin/master 的内容: 工作区必须干净, HEAD 必须已推送
[ -z "$(git status --porcelain)" ] || die "工作区有未提交的改动, 先 commit 再发布"
git fetch origin -q
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] \
    || die "本地 HEAD 未推送到 origin/master (git push 后再发布)"

# 2. 服务器源码快进到 origin/master
ssh "$SERVER" "cd '$REMOTE_DIR' && git fetch origin -q && git merge --ff-only origin/master"

# 3. 服务器构建到临时目录, 成功后再覆盖线上目录
ssh "$SERVER" "cd '$REMOTE_DIR' && rm -rf _build/html.new \
    && sphinx-build -q -b html . _build/html.new \
    && rsync -a --delete _build/html.new/ _build/html/ \
    && rm -rf _build/html.new"

# 4. 线上校验
code=$(curl -fsS -o /dev/null -w '%{http_code}' "$BASE_URL/$PAGE") \
    || die "线上访问失败: $BASE_URL/$PAGE"
echo "发布成功: $BASE_URL/$PAGE (HTTP $code)"
