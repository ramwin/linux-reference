#### Xiang Wang @ 2017-06-21 10:59:41

### git知识


# blame
```
git blame filepath  # 查看某个文件的修改记录
```

# diff
```
git diff --word-diff
```

# log
* [参考链接](http://blog.sina.com.cn/s/blog_601f224a01012wat.html)
* `git log --graph --pretty=format:"%Cblue%h %Cred%s %Creset----%cn @ %ad" --date=format:'%Y-%m-%d %H:%M'`
* %h %H 简短/完整的哈希字符串

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
    git tag -m "新增公司信息存储功能" v2.0.0
    git tag -l --format="%(tag) %(subject)"
```
