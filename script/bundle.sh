#!/bin/bash


set -ex
current_directory=`basename $(pwd)`
target=~/Desktop/$current_directory.bundle 
current_branch=`git branch --show-current`
git bundle create $target origin/$current_branch...HEAD
git bundle verify $target
