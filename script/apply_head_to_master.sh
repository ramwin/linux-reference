#!/bin/bash


set -ex

CURRENT=`git branch --show-current`
git checkout master
git cherry-pick $CURRENT
git checkout $CURRENT
git rebase master
