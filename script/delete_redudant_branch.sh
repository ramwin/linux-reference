#!/bin/bash
# Xiang Wang(ramwin@qq.com)

set -e

rebase_to_master.sh

for branch_name in $( git branch --format="%(refname:short)" --merged | grep -v 'master' ); do
    echo "处理分支:" $branch_name
    git branch -D $branch_name
done
