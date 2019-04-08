#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

system=`lsb_release -d | awk '{print $2}'`

if [ $system = 'Ubuntu' ]; then
    echo "当前为ubuntu系统 $system"
    remote="/media/wangx/WX/github/"
else
    echo "当前为manjaro系统 $system"
    remote="/run/media/wangx/WX/github/"
fi

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
    git pull -q WX master
    pushresult=`git push -q WX master`
    if [[ $pushresult ]]; then
        echo "提交成功"
    else
        echo "请检查 $1"
    fi
}

for project in `ls ..`; do
    echo ""
    echo "处理$project"
    if [ -f "../$project" ]; then
        echo "文件$project不处理"
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
    # git gc
    # git config core.filemode false;
    # git pull origin master
    # git push origin master
    # git remote add WX 
    remote_dir="$remote$project.git"
    checkWx $remote_dir
    runGit $project
done
