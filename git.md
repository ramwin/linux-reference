**Xiang Wang @ 2017-06-21 10:59:41**

[git官网](https://git-scm.com/doc)  
[git reference](https://git-scm.com/docs)  
[git book](https://git-scm.com/book/en/v2)

```shell
忽略某个文件
git update-index --assume-unchanged config.php
```

### [lfs](https://git-lfs.github.com/)
处理大文件用. 

#### 原理
1. 每次add的时候，会计算文件的sha256sum, 保存到 `.git/lfs/objects/98/41/984132.....` 文件。`984132...`是sha256sum的结果
2. 每次commit的时候，git都会文件当做一个指针文件保存到 `.git/objects`, 文件格式:. 所以指针文件126到140字节左右

```
version https://git-lfs.github.com/spec/v1
oid sha256:982144ca336922b975109ac8a8f77576265668cd966885701d8ac75b9c867802
size 6
```

3. 上传的时候，如果服务器的 `.git/lfs/objects/` 文件不存在，那就上传。
4. 下载的时候，根据lfs.fetchinclude配置，来判断拉取文件还是仅仅把文件设置成指针

#### 配置
* 编辑.gitattributes

```
.gitattributes filter= diff= merge= text
* filter=lfs diff=lfs merge=lfs -text
```

* 初始化
```
git lfs install
git lfs track "*.jpg" "*.png" "*.exe" "*.JPG" "*.iso"
git add .
git commit -m '初始化'
```

#### 使用
* 输出pointer
```
$ git lfs clean < 123.txt
version https://git-lfs.github.com/spec/v1
oid sha256:181210f8f9c779c26da1d9b2075bde0127302ee0e3fca38c9a83f5b1dd8e5d3b
size 4
```

* 还原特定文件
```
git lfs checkout <path>
```

* 拉取特定文件
```
git lfs pull --include "windows软件/Git.exe"
```

* 克隆项目
```
git lfs clone <repository> --exclude "*"  # 所有的大文件都不拉
```

* 拉去项目
```
git config lfs.fetchexclude "*"  # 只拉取文件hash, 不拉取整个文件
git pull origin master
```

* 迁移项目
```
git lfs migrate import  # 把git大对象变成lfs指针
```

* 上传项目
```
git push origin master  # 上传git object和lfs对象
git push origin master --no-verify  # 直接上传git object, 不上传lfs对象并且不校验, 因为我的服务器没有开启git-lfs https服务
```


### 通用

#### [field names](https://git-scm.com/docs/git-for-each-ref#_field_names)
* creatordate

### 配置 Setup and Config

#### config
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
### 获取或者创建项目 getting and creating projects

#### init
* [如何更改.git文件夹位置](https://stackoverflow.com/questions/40561234/can-you-change-git-folder-location)
```
git init <directory>  # 初始化仓库
git init --separate-git-dir=/path/to/dot-git-directory .  # 设置.git文件夹的地方
```

* 创建自己的git服务器

    ```
    [root:~/] sudo adduser git
    [git:~/] git init --bare repository.git
    [root:~/] vim /etc/passwd  # change git line to 'git:x:1001:1001:,,,:/home/git:/bin/bash'
    ```

### 快照 Basic Snapshotting

#### commit
* add 后查看修改: `git diff --cached`

* 多次提交很简单的代码 `git commit --amend  # 这样就能修改上次提交的信息，不创建新版本`

* 提交了一次错误的版本 `git revert <commitid>  # 把那次commit之后的修改都reset掉，并生成一个新的commit`

* [git如何生成sha1](https://gist.github.com/masak/2415865)
```
(printf "commit %s\0" $(git cat-file commit HEAD | wc -c); git cat-file commit HEAD) | sha1sum
```

#### diff
```
git diff --word-diff
git diff HEAD HEAD^^ --stat  # only see the different name
```

#### difftool

```
git config diff.tool vimdiff
git difftool HEAD^ HEAD  # 用vimdiff横向比较文件
```

#### [notes](https://git-scm.com/docs/git-notes)
在原有的commit基础上添加备注，而不修改原有commit
```
git notes add -m "这个commit不可用"
```
* [服务器同步notes](https://stackoverflow.com/questions/18268986/git-how-to-push-messages-added-by-git-notes-to-the-central-git-server)
```
git push <remote> refs/notes/*
git fetch origin refs/notes/*:refs/notes/*
```

### 分支和合并 Branching and Merging

#### branch
```
git branch [branchname] [startpoint]  # 指定从哪个版本里开出一个新的分支
```

#### checkout
* 把文件还原到之前的某个版本
```
git checkout versin -- file1/to/restore file2/to/restore
```
* 把已经add的文件还原到没add的状态
```
git reset HEAD filename
```

#### [merge](https://git-scm.com/docs/git-merge)
合并分支

#### [tag](https://git-scm.com/docs/git-tag)  
[文档](https://git-scm.com/book/en/v2/Git-Basics-Tagging)  

* `--sort=<key>`
> 这里的排序使用的是和`git for-each-ref`一致的key  
> 使用`git config tag.sort`可以设置tag的默认排序  

    git config tag.sort -creatordate
    git tag -n | head -n 10

* Listing Your Tags

    git tag [-l] or [-list]
    git tag -l "v1.8.5*"  这时候的-l就必须存在了。

* Creating tags
git支持2种tag, *lightweight* 和 *annotated*

* Creating Annotated Tags
annotated tag会保留谁在什么时候提交的tag

    git tag -a v1.4 -m "version 1.4"
    git show v1.4

* Creating Lightweight Tags
这个lightweight tag仅仅是保存一个标签。就没有谁创建的tag这种信息了

    git tag v1.4-lw


* Tagging Later

    git tag -a v1.2 <checksum> 给指定的某个提交添加tag


* Sharing Tags
默认情况下`git push`不会上传tag到服务器

    git push origin v1.5
    git push origin --tags


* Deleting Tags

    git tag -d v1.4-lw  # 默认不会删除服务器的tag
    git push origin :refs/tags/v1.4-lw
    git push origin --delete <tagname>


* Checkouting out tags

    git checkout 2.0.0


* 其他

    git tag -n
    git tag -m "新增公司信息存储功能" v2.0.0
    git tag -l --format="%(tag) %(subject)"


#### [worktree](https://git-scm.com/docs/git-worktree)
用于突然要维护一个旧分支, 又不想影响当前的工作区

    git worktree add hotfix <hash>  # 先用已有git checkout一次
    cd hotfix  # 进入分支目录修复bug
    ...
    git worktree prune  # 修复后删除

### Sharing and Updating Projects

#### fetch
* 拉取指定的commit
`git fetch --depth=1 <remote> $SHA1`
* 拉去指定的tag
```
git fetch origin refs/tags/1.0.0
```

#### push 推送

* 推送指定分支 `git push origin <local_branch>:<remote-branch> <local_branch2>:<remote-branch2>`

#### 子模块 submodule
* [guide文档](https://git-scm.com/docs/gitsubmodules)
* [命令参考](https://git-scm.com/docs/git-submodule)
* 配置
```
git config submodule.recurse true  # 这样在外层git checkout会导致submodule也checkout
```

* add
```
git submodule add git@ramwin.com:~/small.git  # 这样会clone整个small
```

* clone
```
git clone <repository>  # submodule只会clone一个hash
git clone --recurse-submodules  # 每个submodule都会clone下来
git pull origin master --recurse-submodules  # 每个submodule都pull
git checkout <hash> --recurse-submodules  # 每个submodule都checkout
```

* init
```
git submodule init <submodule>  # 初始化small仓库
```

* foreach
循环对每个submodule执行
```
git submodule foreach git clean -df
```

* update
```
git submodule update small  # 初始化后，可以clone
```
* [手动添加一个仓库](https://stackoverflow.com/questions/34562333/is-there-a-way-to-git-submodule-add-a-repo-without-cloning-it)
```
git update-index --add --cacheinfo 160000 d020b3a97f131ad11fb15bd8cce1774b0eb54c7b small
git commit -m '先加上去再说'  # 此时.git/index文件里显示有个submodule, 但是呢，工作区显示small文件夹不存在
```


### 查看和比较 Inspection and Comparison
* [show](https://git-scm.com/docs/git-show)
```
git show <ref>  # 查看某个版本的修改
git show <ref>:<file>  # 查看某个版本的文件
```
#### [log](https://git-scm.com/docs/git-log)
git log HEAD^ 是按照第一个parent依次往前找的，而不是按照时间顺序找的
git log 是按照时间顺序往前找的

* [参考链接](http://blog.sina.com.cn/s/blog_601f224a01012wat.html)
* `git log --graph --pretty=format:"%Cblue%h %Cred%s %Creset----%cn @ %ad" --date=format:'%Y-%m-%d %H:%M' %d`
* %h %H 简短/完整的哈希字符串
* %d %D ref的name, %D代表了不用括号括起来


### Patching

#### [cherry-pick](https://git-scm.com/docs/git-cherry-pick)
把某次提交的功能应用当前版本

```
git cherry-pick <commit>
```

#### rebase
[官网](https://git-scm.com/docs/git-rebase)
* 基础
```
git rebase --onto <newbase> <branch>
git rebase --onto <newbase> <hash1> <branch> # 把branch从hash1开始(不包含)到结束的commit应用到newbase上
```
* 合并几个commit
```
git rebase -i HEAD^^^  # 然后只pick第一个，squash后面所有的
```

#### revert
* 撤回上个版本
```
git revert HEAD
```
* 连续撤回前2个版本，生成2个commit
```
git revert HEAD^^...HEAD  # 注意前开后闭区间
```
* 撤回但是不自动生成commit, 方便你连续revert多个commit时，只希望生成个commit
```
git revert -n/--no-commit HEAD^^...HEAD
```

### 排查 Debugging

#### bisect
通过二分法找到出现bug的版本
```
git bisect start  # 开始寻找
git bisect bad  # 当前版本报错
git bisect good 1.0.0  # 1.0.0版本不报错
...
git bisect reset  # 找到报错版本后，推出bisect
```

#### blame
```
git blame filepath  # 查看某个文件的修改记录
```

### Administration

#### [clean](https://git-scm.com/docs/git-clean)  
清理untracked文件
```
git clean -dfxn
git clean -dfx
-n dry run
-i 交互模式,每个都问你
-f 强制删除(一般需要，clean.requireForce默认开了)
-d 多余的文件夹也删除
-x 包括ignore的文件也删除
```

#### gc
```
git gc  # 优化仓库
```

#### [ ] fsck

#### [bundle](https://git-scm.com/book/zh/v2/Git-%E5%B7%A5%E5%85%B7-%E6%89%93%E5%8C%85)
但是不支持lfs

```shell
git bundle create <filename> master ^commit  # 把从commit到master的版本打包
git bundle verify bundle  # 查看打包的文件
git fetch <filename> master:other-master  # 把bundle文件中的master分支复制到本地other-master分支
```

### 其他插件 Plumbing Commands
* hash-object
生成一个文件的hash

```shell
echo -e "blob 2\0A" > A_blob
sha1sum A_blob  >> f70f10e4db19068f79bc43844b49f3eece45c4e8
echo "A" > A
git hash-object A >> f70f10e4db19068f79bc43844b49f3eece45c4e8
```

* [merge-base](https://git-scm.com/docs/git-merge-base)
找到多个节点的共同祖先

```
git merge-base commitA commitB
```

### ls-remote
展示远程仓库的分支和tag

### pull
* 拉取远程分支 `git pull origin <branch>:<local_branch>`


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
git stash --all  # 包含ignored和untracked
git stash -- <file1> [<file2>]  # 指定部分文件stash
git stash -u/--include-untracked 包含untracked文件
```

### 其他
* [ ] working with remotes
* [ ] git aliases
* 彻底删除某个文件
```
    git filter-branch --tree-filter 'rm -f <filename>' HEAD
    git push -f
```
* 找到大文件
```
    git rev-list --objects --all | grep "$(git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -n | tail -5 | awk '{print$1}')"
```
