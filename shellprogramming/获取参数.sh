#!/bin/bash
# Xiang Wang(ramwin@qq.com)


param=$1

if [ ! $param ]
then
    read -p "输入参数: " param
fi

echo "参数" $param
