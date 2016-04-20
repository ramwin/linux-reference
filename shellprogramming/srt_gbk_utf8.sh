#!/bin/bash
# Xiang Wang @ 2016-04-10 19:15:46

ls -1 | grep .srt | while read fn; do
    name=$fn
    # echo $name
    a=""
    a=$(chardet3 "${name}")
    a=${a/${name}/name}
    a=${a#* }
    a=${a%% *}
    echo $a
    target="${name/.srt/utf8.srt}"
    echo $name
    echo $target
    iconv -f $a -t utf-8 -o "$target" "$name"
    # echo "$fn.utf-8"
done
