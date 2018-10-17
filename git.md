**Xiang Wang @ 2017-06-21 10:59:41**

# blame
```
git blame filepath  # 查看某个文件的修改记录
```

# checkout
* 把文件还原到之前的某个版本
```
git checkout versin -- file1/to/restore file2/to/restore
```
* 把已经add的文件还原到没add的状态
```
git reset HEAD filename
```

# commit
* add 后查看修改: `git diff --cached`

* 多次提交很简单的代码 `git commit --amend  # 这样就能修改上次提交的信息，不创建新版本`

* 提交了一次错误的版本 `git rever <commitid>  # 把那次commit之后的修改都reset掉，并生成一个新的commit`

# config
* 设置用户名邮箱:
```
git config --global user.email "ramwin@qq.com"
git config --global user.name "Xiang Wang"
```
* 设置默认的 pull 和 push
```
git branch --set-upstream-to=origin/origin master
git config --global push.default matching
```

* git中文不显示utf8编码而显示中文: `git config --global core.quotepath false`

* 设置忽略文件权限修改: `git config core.filemode false`

* 全局设定
```
设置 .gitconfig
    [core]
        excludesfile = ~/.gitignore_global
        bigFileThreshold = 1m  # 超过1M的文件不再当作文本去记录变化
编辑 .gitignore_global
```

* 服务器允许pull指定的commit
uploadpack.allowReachableSHA1InWant=true

# diff
```
git diff --word-diff
git diff HEAD HEAD^^ --stat  # only see the different name
```

# fetch
* 拉取指定的commit
`git fetch --depth=1 <remote> $SHA1`

# log
* [参考链接](http://blog.sina.com.cn/s/blog_601f224a01012wat.html)
* `git log --graph --pretty=format:"%Cblue%h %Cred%s %Creset----%cn @ %ad" --date=format:'%Y-%m-%d %H:%M'`
* %h %H 简短/完整的哈希字符串

# ls-remote
展示远程仓库的分支

# pull
* 拉取远程分支 git pull origin <branch>:<local_branch>

# status
* `git status -s, --short` *只显示文件名，而不显示其他多余的信息*

# stash
```
git stash
git stash list
git stash pop = git stash apply; git stash drop
```


# tag
```
    git tag -n
    git tag -m "新增公司信息存储功能" v2.0.0
    git tag -l --format="%(tag) %(subject)"
```

# 文件处理
* 彻底删除某个文件
```
    git filter-branch --tree-filter 'rm -f <filename>' HEAD
    git push -f
```
* 找到大文件
```
    git rev-list --objects --all | grep "$(git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -n | tail -5 | awk '{print$1}')"
```

# gc
```
git gc  # 优化仓库
```
