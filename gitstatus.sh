#!/bin/bash
# Xiang Wang @ 2016-05-31 14:37:07

project=(`ls ..`);
len=${#project[*]};
i=0;
while [ $i -lt $len ]; do
    echo ../${project[$i]}
    cd ../${project[$i]}
    git config core.filemode false;
    git status;
    let i++
done
