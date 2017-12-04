#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

for project in `ls ..`
do
    if [ "$project" = "other" ]; then
        continue
    fi
    echo "正在查看项目:" $project;
    cd ../${project}
    git gc
    git config core.filemode false;
    git pull origin master
    git push origin master
    git status
    echo ""
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
