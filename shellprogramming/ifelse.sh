#!/bin/bash
# Xiang Wang @ 2019-06-18 16:33:32

a=10
b=20
c=10
if [ $a == $c ]
then
    echo "a==c"
else
    echo "a!=c"
fi

if [ '中国'='中国' ]
then
    echo '中国==中国'
fi
