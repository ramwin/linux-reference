#!/bin/bash
# Xiang Wang(ramwin@qq.com)


set -e


set_masterbranch()
{
    for branchname in $( git branch --format="%(refname:short)" );
    do
        if [ "$branchname" = "master" ]
        then
            export masterbranch="master"
        elif [ "$branchname" = "main" ]
        then
            export masterbranch="main"
        fi
    done
}

set_masterbranch
echo "当前主干分支"$masterbranch $HOME
git checkout $masterbranch
# git pull origin $masterbranch

for branch_name in $( git branch --format="%(refname:short)" | grep -v '$masterbranch' ); do
    git checkout $branch_name
    git rebase $masterbranch
done
