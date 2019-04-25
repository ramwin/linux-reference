#!/bin/bash
# Xiang Wang @ 2019-04-25 17:48:19


checkStatus() {
    status=`git status --porcelain` 
    if [[ $status ]]; then
        echo "有编辑"
        echo $status
    else
        echo "没有编辑"
    fi
}

checkStatus
