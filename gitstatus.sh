#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

for project in `ls ..`; do
    echo "处理$project"
    if [ -f "../$project" ]; then
        # echo "文件$project不处理"
        continue
    fi
    if [ "$project" = "other" ]; then
        # echo "其他人的项目不处理"
        continue
    fi
    cd ../${project}
    # git gc
    # git config core.filemode false;
    # git pull origin master
    # git push origin master
    # git remote add WX 
    remote_dir="/media/wangx/WX/github/$project.git"
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
        echo "git init --bare /media/wangx/WX/github/$project.git"
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
