#!/bin/bash
# Xiang Wang @ 2019-04-25 17:48:19


checkStatus() {
    # 这个只会看暂存区，工作区是否有编辑
    status=`git status --porcelain` 
    if [[ $status ]]; then
        echo "当前暂存区或者工作区有改动"
        echo $status
    else
        echo "没有编辑"
    fi
}

pull() {
    echo "pull"
    local result=`git pull -q origin master`
    echo $result
    if [[ $result ]]; then
        echo "拉取到了新代码"
    else
        echo "没有拉取到新代码"
    fi
    echo "pull结束"
}

diffCheck() {
    echo "检查"
    local origindiff=`git diff --exit-code --shortstat origin/master`
    if [[ $origindiff ]]; then
        echo $origindiff
        echo "和origin不一样"
    else
        echo "和origin一样"
    fi
    local WXdiff=`git diff --exit-code --shortstat WX/master`
    if [[ $WXdiff ]]; then
        echo $WXdiff
        echo "和WX不一样"
    else
        echo "和WX一样"
    fi
}

checkStatus
pull
diffCheck
