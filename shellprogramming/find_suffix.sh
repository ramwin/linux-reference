#!/bin/bash
# Xiang Wang(ramwin@qq.com)

# filenames=($(find . -type f -not -path './.git/*'))
# # echo ${filenames[0]}
# for i in ${filenames[*]}; do
#     echo ${i} | sed "s/^.&\.//"
# done

find . -type f -not -path './.git/*' | grep "^\..*\." | sed 's/^.*\.//' | sort | uniq
