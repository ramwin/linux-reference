**Xiang Wang @ 2017-06-21 10:59:41**

[git官网](https://git-scm.com/doc)  
[git reference](https://git-scm.com/docs)  
[git book](https://git-scm.com/book/en/v2)

### 通用
#### [field names](https://git-scm.com/docs/git-for-each-ref#_field_names)
* creatordate

### 分支和合并 Branching and Merging
#### [tag](https://git-scm.com/docs/git-tag)
* `--sort=<key>`
> 这里的排序使用的是和`git for-each-ref`一致的key  
> 使用`git config tag.sort`可以设置tag的默认排序  
```
git config tag.sort -creatordate
git tag -n | head -n 10
```


### 查看和比较 Inspection and Comparison
* [show](https://git-scm.com/docs/git-show)
```
git show <ref>  # 查看某个版本的修改
git show <ref>:<file>  # 查看某个版本的文件
```
* [log](https://git-scm.com/docs/git-log)
    * [参考链接](http://blog.sina.com.cn/s/blog_601f224a01012wat.html)
    * `git log --graph --pretty=format:"%Cblue%h %Cred%s %Creset----%cn @ %ad" --date=format:'%Y-%m-%d %H:%M' %d`
    * %h %H 简短/完整的哈希字符串
    * %d %D ref的name, %D代表了不用括号括起来

### init
* [如何更改.git文件夹位置](https://stackoverflow.com/questions/40561234/can-you-change-git-folder-location)
```
git init <directory>  # 初始化仓库
git init --separate-git-dir=/path/to/dot-git-directory .  # 设置.git文件夹的地方
```

### blame
```
git blame filepath  # 查看某个文件的修改记录
```

### checkout
* 把文件还原到之前的某个版本
```
git checkout versin -- file1/to/restore file2/to/restore
```
* 把已经add的文件还原到没add的状态
```
git reset HEAD filename
```

### commit
* add 后查看修改: `git diff --cached`

* 多次提交很简单的代码 `git commit --amend  # 这样就能修改上次提交的信息，不创建新版本`

* 提交了一次错误的版本 `git rever <commitid>  # 把那次commit之后的修改都reset掉，并生成一个新的commit`

### branch
```
git branch [branchname] [startpoint]  # 指定从哪个版本里开出一个新的分支
```

### config
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
编辑 `.gitignore_global`
```

* 服务器允许pull指定的commit
uploadpack.allowReachableSHA1InWant=true

* core.compression 和 core.looseCompression
只要设置了core.compression, 得到的pack就是一样的, 但是md5和原始文件不同
    * test 文件夹, 默认, 一个windows10安装包 4.7G(5,010,587,648), 联想的普通机械硬盘, origin是同一个文件夹下面的另外一个文件夹
    ```
    git add .  # 耗时3分20秒
    git commit -m "" # 立马结束
    objects/pack-c36dxxx76f5.pack 4.6G 4953058178字节
    git push origin master  # 耗时6分21秒
    objects/85/44441acexxxx3c21 4954989512字节
    test_origin的配置
        user.name=Xiang Wang
        user.email=ramwin@qq.com
        core.quotepath=false
        core.filemode=false
        core.excludesfile=~/.gitignore_global
        core.bigfilethreshold=200K
        pack.windowmemory=1g
        core.repositoryformatversion=0
        core.filemode=true
        core.bare=true
    ```

    * test1 文件夹, 都设置成0
    ```
    git add .  # 耗时1分25秒
    git commit -m "" # 立马结束
    pack-5854xxx2d65.pack 4.7G 5011352247字节
    git push origin master  # 耗时6分17秒
    objects/85/44441acexxxx3c21  4954989512字节
    test_origin1的配置
        user.name=Xiang Wang
        user.email=ramwin@qq.com
        core.quotepath=false
        core.filemode=false
        core.excludesfile=~/.gitignore_global
        core.bigfilethreshold=200K
        pack.windowmemory=1g
        core.repositoryformatversion=0
        core.filemode=true
        core.bare=true
    test_origin2的配置
        user.name=Xiang Wang
        user.email=ramwin@qq.com
        core.quotepath=false
        core.filemode=false
        core.excludesfile=~/.gitignore_global
        core.bigfilethreshold=200K
        pack.windowmemory=1g
        core.repositoryformatversion=0
        core.filemode=true
        core.bare=true
        core.compression=0
        core.loosecompression=0
    git push origin2 master  # 耗时4分11秒
    objects/85/44441acexxxx3c21 5011352225字节
    ```


### diff
```
git diff --word-diff
git diff HEAD HEAD^^ --stat  # only see the different name
```

### fetch
* 拉取指定的commit
`git fetch --depth=1 <remote> $SHA1`


### ls-remote
展示远程仓库的分支

### pull
* 拉取远程分支 git pull origin <branch>:<local_branch>

### show  
查看某个文件的版本
```
git show ref:filepath > tmp
```

### status
* `git status -s, --short` *只显示文件名，而不显示其他多余的信息*

### [stash](https://git-scm.com/docs/git-stash)
```
git stash
git stash list
git stash pop = git stash apply; git stash drop
git stash --all  # 把新建的文件也stash掉
git stash -- <file1> [<file2>]  # 指定部分文件stash
```


### [tag](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
* Listing Your Tags
```
git tag [-l] or [-list]
git tag -l "v1.8.5*"  这时候的-l就必须存在了。
```
* Creating tags
git支持2种tag, *lightweight* 和 *annotated*

* Creating Annotated Tags
annotated tag会保留谁在什么时候提交的tag
```
git tag -a v1.4 -m "version 1.4"
git show v1.4
```

* Creating Lightweight Tags
这个lightweight tag仅仅是保存一个标签。就没有谁创建的tag这种信息了
```
git tag v1.4-lw
```

* Tagging Later
```
git tag -a v1.2 <checksum> 给指定的某个提交添加tag
```

* Sharing Tags
默认情况下`git push`不会上传tag到服务器
```
git push origin v1.5
git push origin --tags
```

* Deleting Tags
```
git tag -d v1.4-lw  # 默认不会删除服务器的tag
git push origin :refs/tags/v1.4-lw
git push origin --delete <tagname>
```

* Checkouting out tags
```
git checkout 2.0.0
```

* 其他
```
git tag -n
git tag -m "新增公司信息存储功能" v2.0.0
git tag -l --format="%(tag) %(subject)"
```

### 文件处理
* 彻底删除某个文件
```
    git filter-branch --tree-filter 'rm -f <filename>' HEAD
    git push -f
```
* 找到大文件
```
    git rev-list --objects --all | grep "$(git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -n | tail -5 | awk '{print$1}')"
```

### gc
```
git gc  # 优化仓库
```

### 服务器
    * build your git server
    ```
    [root:~/] sudo adduser git
    [git:~/] git init --bare repository.git
    [root:~/] vim /etc/passwd  # change git line to 'git:x:1001:1001:,,,:/home/git:/bin/bash'
    ```

### 其他
* [ ] working with remotes
* [ ] git aliases
