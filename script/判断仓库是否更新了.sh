#!/bin/bash
# Xiang Wang(ramwin@qq.com)

repo_updated=""
function updated()
{
    directoryname=`basename $(pwd)`
    current=`git log -1 --format="%H"`
    cache_file=/tmp/$directoryname
    if [ -f $cache_file ];
    then
        last=`cat $cache_file`
    else
        last=""
    fi
    if [[ $current = $last ]];
    then
        repo_updated="false"
        echo "一样的"
    else
        repo_updated="true"
        echo "代码仓变成了"$current
        echo $current > $cache_file
    fi
}

updated
echo $repo_updated
