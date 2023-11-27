#!/bin/bash
# Xiang Wang(ramwin@qq.com)


set -e

git checkout master
git pull origin master

for branch_name in $( git branch --format="%(refname:short)" | grep -v 'master' ); do
    git rebase master
done
