**Xiang Wang @ 2018-05-04 19:52:09**

# [circle](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-7.html)
```
for i in $( ls ); do
    if [ -d $i ]; then
        echo "directory: "
    elif [ $i = 'certainname' ]; then
    else
        echo "file: "
    fi
    echo item: $i
done
```

# [判断](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-6.html#ss6.3)
```
if [ "foo" = "foo" ]; then  # 中括号旁边必须有空格,等号前后也必须有空格, 而且只有一个等号
else
fi
```
