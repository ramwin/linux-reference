#!/bin/bash
# Xiang Wang @ 2016-03-27 19:57:04

array=(red green blue yellow magenta)
# array=(`ls`)
len=${#array[*]}
echo "The array has $len members. They ars:"
i=0
while [ $i -lt $len ]; do
    echo "$i: ${array[$i]}"
    let i++
done


for i in $( ls ); do
    echo $i
done

for i in "cmatrix" "python2"; do
    echo $i
done

# 过滤掉列表中的某一个
echo "输出array的列表"
array=(string1 string2 string3)
for i in ${array[*]};
do
    echo $i
done

# 退出多重循环
line1=(string1 string2 string3)
line2=(string4 string2 string1)
for i in ${line1[*]};
do
    echo "查看line1的${i}"
    for j in ${line2[*]};
    do
        echo "查看line2的${j}"
        if [ $i == $j ]; then 
            echo "line1的${i}和Line2的${j}相同"
            break 2  # break后面的数字代表停多少次循环, 默认为1
        fi
    done
done

echo "# 继续单重循环"
for i in ${line1[*]};
do
    echo "查看line1的${i}"
    for j in ${line2[*]};
    do
        echo "    查看line2的${j}"
        if [ $i == $j ]; then 
            echo "    line1的${i}和Line2的${j}相同, 不再循环Line2"
            continue 2  # break后面的数字代表停多少次循环, 默认为1
        fi
    done
    echo "line1的${i}处理结束"
done
