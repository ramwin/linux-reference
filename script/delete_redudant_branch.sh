#!/bin/bash
# Xiang Wang(ramwin@qq.com)
#
# 这个文件名是保留兼容的入口: 真正的实现已改名为 delete_redundant_branch.sh.
# 旧版本的第一行是 `rebase_to_master.sh`(会把所有分支 rebase 到 master)、
# 然后 `git checkout master` 再删, 副作用大且没有 dry-run / 备份, 已废弃.
# 新版本默认只报告, 加 --yes 才删, 删前自动备份到 refs/backup/branch-cleaner/。
exec "$(cd "$(dirname "$0")" && pwd)/delete_redundant_branch.sh" "$@"
