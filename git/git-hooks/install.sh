#!/usr/bin/env bash
# 把 commit-msg hook 安装到 ~/.git-hooks/ 并配置全局 hooksPath
# 用法: ./git-hooks/install.sh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hooks_dir="$HOME/.git-hooks"

mkdir -p "$hooks_dir"
install -m 755 "$script_dir/commit-msg" "$hooks_dir/commit-msg"
git config --global core.hooksPath "$hooks_dir"

echo "已安装: $hooks_dir/commit-msg"
echo "core.hooksPath = $hooks_dir (全局)"
