#!/usr/bin/env bash
# Xiang Wang(ramwin@qq.com)
#
# 发布 linux-reference 文档到 https://linux-reference.ramwin.com
#
# 线上由服务器自己的 systemd timer 部署:docs-autodeploy@linux-reference.timer
# 每 5 分钟 git 拉一次 origin/master,有新提交才跑仓内 自动发布.sh(sphinx 构建)。
# 所以手动发布 = 确认已 push + 立刻触发一次部署(不用等定时器)。
#
# 用法: ./发布.sh [要校验的页面路径, 默认 ai/]
#   DOCS_SERVER / DOCS_BASE_URL 可覆盖默认值
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

SERVER="${DOCS_SERVER:-ramwin}"
SITE=linux-reference
BASE_URL="${DOCS_BASE_URL:-https://linux-reference.ramwin.com}"
PAGE="${1:-ai/}"

die() { echo "error: $*" >&2; exit 1; }

# 1. 线上只发布 origin/master 的内容: 工作区必须干净, HEAD 必须已推送
[ -z "$(git status --porcelain)" ] || die "工作区有未提交的改动, 先 commit 再发布"
git fetch origin -q
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] \
    || die "本地 HEAD 未推送到 origin/master (git push 后再发布)"

# 2. 立刻跑一次服务器端部署(没新提交时脚本会直接跳过构建)
ssh "$SERVER" "sudo -n systemctl start docs-autodeploy@$SITE.service \
    && sudo -n journalctl -u docs-autodeploy@$SITE.service -n 6 --no-pager -o cat"

# 3. 核对线上构建的 commit 就是这次 push 的 commit
built=$(ssh "$SERVER" "cat /var/lib/docs-deploy/$SITE.built 2>/dev/null" || true)
[ "$built" = "$(git rev-parse HEAD)" ] \
    || die "线上构建版本($built)与 HEAD($(git rev-parse HEAD))不一致, 查 sudo journalctl -u docs-autodeploy@$SITE"

# 4. 线上校验
code=$(curl -fsS -o /dev/null -w '%{http_code}' "$BASE_URL/$PAGE") \
    || die "线上访问失败: $BASE_URL/$PAGE"
echo "发布成功: $BASE_URL/$PAGE (HTTP $code)"
