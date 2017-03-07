# add 后查看修改
    git diff --cached

# 多次提交很简单的代码
    git commit --amend  # 这样就能修改上次提交的信息，不创建新版本

# 提交了一次错误的版本
    git rever <commitid>  # 把那次commit之后的修改都reset掉，并生成一个新的commit
