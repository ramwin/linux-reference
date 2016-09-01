# add 后查看修改
    git diff --cached

# 多次提交很简单的代码
    git commit --amend  # 这样就能修改上次提交的信息，不创建新版本

# 临时保存内容去看其他分支
    git stash
    git stash list
    git stash apply
    git stash drop
    git stash pop   # 等于 `git stash apply` 后 `git stash drop`
