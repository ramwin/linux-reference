#!/bin/bash
# Xiang Wang @ 2016-03-27 19:57:04

array=(red green blue yellow magenta)
array=(`ls`)
len=${#array[*]}
echo "The array has $len members. They ars:"
i=0
while [ $i -lt $len ]; do
    echo "$i: ${array[$i]}"
    let i++
done

