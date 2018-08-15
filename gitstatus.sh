#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

for project in `ls ..`; do
    echo "正在查看项目:$project";
    if [ -f "../$project" ]; then
        echo "文件$project不处理"
        continue
    fi
    if [ "$project" = "other" ]; then
        echo "其他人的项目不处理"
        continue
    fi
    cd ../${project}
    # git gc
    # git config core.filemode false;
    # git pull origin master
    # git push origin master
    git status -s
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
