#!/bin/bash
# Xiang Wang @ 2016-03-18 22:01:05

echo "Hello, world."

if [ -e basic02 ] # 是否存在basic02这个文件
# if test -e . # [ ] 和 test 一样
then
    echo "存在basic02"
else
    echo "不存在basic02"
fi
