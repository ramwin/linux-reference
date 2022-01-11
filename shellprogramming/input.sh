#!/bin/bash
# Xiang Wang(ramwin@qq.com)

while [ true ]; do
    read text;
    if [ $text = 'exit' ]; then
        exit 0;
    fi
    echo "您输入了: " $text;
done
