#!/bin/bash
# Xiang Wang(ramwin@qq.com)



masterbranch=""
master_exist=0
main_exist=0

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

declare -x masterbranch=$masterbranch
echo "masterbranch = "$masterbranch
