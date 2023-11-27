#!/bin/bash
# Xiang Wang(ramwin@qq.com)

set -e

git checkout master
git pull origin master
for branch_name in $( git branch --format="%(refname:short)" | grep -v 'master' ); do
    echo "处理分支:" $branch_name
    git checkout $branch_name
    git rebase master
    git checkout master
    git branch -d $branch_name
done
