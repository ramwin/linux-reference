#!/bin/bash
# Xiang Wang(ramwin@qq.com)

directoryname=`basename $(pwd)`
current=`git log -l 1 --format="%H"`
cache_file=/tmp/$directoryname
last=`cat $cache_file`
if [ $current == $last ];
then
    echo "一样的"
else
    echo "代码仓变成了"$current
    echo $current > $cache_file
fi
