#!/bin/bash
# Xiang Wang(ramwin@qq.com)

set -ex

rebase_to_master.sh
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

git checkout $masterbranch
# export masterbranch="main"
for branch_name in $( git branch --format="%(refname:short)" --merged | grep -v $masterbranch ); do
    echo "处理分支:" $branch_name
    git branch -d $branch_name
done
