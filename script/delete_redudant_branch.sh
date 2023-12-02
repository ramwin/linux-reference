#!/bin/bash
# Xiang Wang(ramwin@qq.com)

set -e

rebase_to_master.sh
git checkout master

for branch_name in $( git branch --format="%(refname:short)" --merged | grep -v 'master' ); do
    echo "处理分支:" $branch_name
    git branch -d $branch_name
done
