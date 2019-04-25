#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

system=`lsb_release -d | awk '{print $2}'`

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

if [ $system = 'Ubuntu' ]; then
    echo "当前为ubuntu系统 $system"
    remote="/media/wangx/WX/github/"
else
    echo "当前为manjaro系统 $system"
    remote="/run/media/wangx/WX/github/"
fi

checkRemote $remote

checkGitRemote() {
    # echo "检查git项目里是否存在 WX remote"
    remotes=`git remote show | grep '^WX$'`
    if [ ! $remotes ]; then
        echo "不存在git remote WX"
        exit 1 
    fi
}

checkGitStatus() {

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
            echo "文件夹${i}不处理"
            continue 2
        fi
    done
    cd ../${project}
    remote_dir="$remote$project.git"
    checkGitRemote
    checkGitStatus
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
# echo $project
# len=${#project[*]};
# i=0;
# echo $len;
# while [ $i -lt $len ]; do
#     echo ../${project[$i]}
#     cd ../${project[$i]}
#     git config core.filemode false;
#     git status;
#     let i++
# done
