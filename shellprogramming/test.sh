#!/bin/bash
# Xiang Wang @ 2018-08-01 10:13:56

if [ -f 'file' ]; then
    echo 'file文件存在'
else
    echo 'file文件不存在'
fi

if [ -d 'directory' ]; then
    echo '目录directory存在'
else
    echo '目录directory不存在'
fi
