#!/bin/bash
# Xiang Wang @ 2016-03-27 20:05:52

# 字符串截断
string="this is a substring test"
substring=${string:10:12}
echo ${substring}

# 字符串替换
alpha="This is a test string in which the word \"test\" is replaced."
beta="${alpha/test/replace}"    # 仅仅替换第一个字符串
echo ${beta}
beta2="${alpha//test/replace}"  # 替换所有字符串
echo ${beta2}

list="cricket frog cat dog"
poem="I wanna be a x\n\
A x is what I'd love to be\n\
How happy I would be.\n"
for critter in $list; do
    echo -e ${poem//x/$critter}
done

# 其他操作
x="This is my test string."
echo ${x#* }    # 从左删除到空格
echo ${x##* }   # 删除到最后一个空格
echo ${x% *}    # 从右边删除到第一个空格
echo ${x%% *}   # 从右删除到最后一个空格
