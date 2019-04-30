#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

system=`lsb_release -d | awk '{print $2}'`
origin=$false

if [ $system = 'Ubuntu' ]; then
    echo "当前为ubuntu系统 $system"
    remote="/media/wangx/WX/github/"
else
    echo "当前为manjaro系统 $system"
    remote="/run/media/wangx/WX/github/"
fi

checkStatus() {
    # 这个只会看暂存区，工作区是否有编辑
    status=`git status --porcelain` 
    if [[ $status ]]; then
        echo -e "\e[91m当前暂存区或者工作区有改动\e[m"
        echo $status
        pwd
    # else
    #     echo "没有编辑"
    fi
}

pull() {
    if [[ $origin ]]; then
        echo "git pull -q origin master"
        local result=`git pull -q origin master`
        if [[ $result ]]; then
            echo -n $result
            echo "拉取到了origin新代码"
        # else
        #     echo "没有拉取到新代码"
        fi
    fi
    local WXresult=`git pull -q WX master`
    if [[ $WXresult ]]; then
        echo -n $WXresult
        echo "拉取到了WX新代码"
    fi
}

push() {
    if [[ $origin ]]; then
        echo "git push -q origin master"
        local result=`git push -q origin master`
        echo -n $result
        if [[ $result ]]; then
            echo -e "\e[91m上传失败\e[m"
        fi
    fi
    local WXresult=`git push -q WX master`
    echo -n $WXresult
    if [[ $result ]]; then
        echo "上传失败"
    fi
}

diffCheck() {
    local origindiff=`git diff --exit-code --shortstat origin/master`
    if [[ $origindiff ]]; then
        echo $origindiff
        echo "和origin不一样"
    # else
    #     echo "和origin一样"
    fi
    local WXdiff=`git diff --exit-code --shortstat WX/master`
    if [[ $WXdiff ]]; then
        echo $WXdiff
        echo "和WX不一样"
        pwd
    # else
    #     echo "和WX一样"
    fi
}

# 第一步，检查远程仓库
checkRemote(){
    echo "检查远程仓库地址 $1 "
    if [ -d "$1" ]; then
        echo "远程仓库地址$1存在"
    else
        echo "远程仓库地址$1不存在"
        exit 123
    fi
}
checkRemote $remote

checkWx(){
    if [[ ! -d $1 ]]; then
        echo "远程仓库不存在"
        echo "git init --bare $1"
        git init --bare $1
    fi
    result=`git remote show WX`
    if [[ ! $result ]]; then
        echo "没有仓库"
        echo "git remote add WX $1"
        git remote add WX $1
    fi
}

runGit() {
    # echo "git push -q --porcelain WX master"
    pushresult=`git push -q --porcelain WX master`
    if [[ $pushresult != 'Done' ]]; then
        echo "请检查 $1"
        exit 1
    fi
}

checkGitRemote() {
    # echo "检查git项目里是否存在 WX remote"
    remotes=`git remote show | grep '^WX$'`
    if [ ! $remotes ]; then
        echo "不存在git remote WX"
        exit 1 
    fi
}


pullPushgit() {
    git pull -q WX master
    git push -q WX master
}

for project in `ls ..`; do
# projects=("html-reference" "linux-reference")
# for project in ${projects[*]} ; do
    echo "处理$project"
    if [ -f "../$project" ]; then
        continue
    fi

    ignore_project=('$RECYCLE.BIN' 'other' 'secret' 'System Volume Information' '王祥')
    for i in ${ignore_project[*]}; do
        if [ "$project" = "$i" ]; then
            # echo "文件夹${i}不处理"
            continue 2
        fi
    done
    cd ../${project}
    remote_dir="$remote$project.git"
    checkStatus
    pull
    push
    diffCheck
    checkGitRemote
    pullPushgit
    continue
    echo "执行完毕"
    exit 1

    status=`git status`
    if [ -d "$remote_dir" ]; then
        echo "远程仓库$remote_dir存在"
        # 第一步，先看看
        # git remote add WX $remote_dir
        git remote set-url WX $remote_dir
        git pull WX master
        git push WX master
        git status
    else
        echo "远程仓库不存在"
        echo "git init --bare $remote$project.git"
        git init --bare $remote$project.git
    fi
    string='string'
    # status="On branch master\nYour branch is up to date with 'origin/master'.\n\nnothing to commit, working tree clean"
    if [ "$status" = $'On branch master\nYour branch is up to date with \'origin/master\'.\n\nnothing to commit, working tree clean' ]; then
        echo "项目$project一切正常"
        continue
    elif [ "$status" = $'On branch master\nnothing to commit, working tree clean' ]; then
        echo "项目$project一切正常"
        continue
    else
        echo "请查看项目$project"
        break
    fi
done
