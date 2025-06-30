#!/bin/bash
# Xiang Wang(ramwin@qq.com)

HOST1="1"
HOST2="2"
HOST3="3"

a=($HOST1 $HOST2 $HOST3)
for var in ${a[@]}; do
    echo "循环"
    echo $var
done
