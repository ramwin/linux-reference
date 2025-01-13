#!/bin/bash
# Xiang Wang(ramwin@qq.com)

set -ex

directory=$1
cd $directory
remote_url=`git remote -v | grep origin | tail -n 1 | awk '{print $2}'`
cd -
git submodule add $remote_url $directory
