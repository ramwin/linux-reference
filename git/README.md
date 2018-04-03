#### Xiang Wang @ 2017-06-21 10:59:41

# tag
```
    git tag -m "新增公司信息存储功能" v2.0.0
    git tag -l --format="%(tag) %(subject)"
```

# diff
```
    git diff --word-diff
```

# status
    * `git status -s, --short` *只显示文件名，而不显示其他多余的信息*

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
