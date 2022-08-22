#!/bin/bash
# Xiang Wang(ramwin@qq.com)


array=`cat input.txt`
# array=(1 2 3)

echo "直接读取input的结果"
echo $array
echo "array的长度 ${#array[@]}"
array=($array)
echo "array的长度 ${#array[@]}"
