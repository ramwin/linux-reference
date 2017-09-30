#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

for project in `ls ..`
do
    if [ "$project" = "other" ]; then
        continue
    fi
    echo $project;
    cd ../${project}
    git config core.filemode false;
    git status -s;
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
