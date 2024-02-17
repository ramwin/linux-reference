#!/bin/bash
# Xiang Wang(ramwin@qq.com)


hostname=`hostname`
echo $hostname
if [ $hostname = 'wangxiang-redmibook14apcs' ]
then
    echo "本地环境"
else
    echo $hostname
    echo "服务器环境"
fi
