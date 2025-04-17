#!/bin/bash


set -ex
current_directory=`basename $(pwd)`
target=~/Desktop/$current_directory.bundle 
git bundle create $target origin/master...HEAD
git bundle verify $target
