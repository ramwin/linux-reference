**Xiang Wang @ 2018-05-04 19:52:09**

# [menu 目录]
* [linux-totorial](../README.md)  
* [runoob 菜鸟网站](https://www.runoob.com/linux/linux-shell.html)
* [ ] [learning website](https://www.shellscript.sh/)

# [variables 变量](https://www.runoob.com/linux/linux-shell-variable.html)
* 赋值变量
```
STR="Hello World!"  # 等号两端不能有空格
echo $STR
OF=/var/my-backup-$(date +%Y%m%d).tgz
tar -cZf $OF /home/me/
# 把语句赋值给变量
version=`lsb_release -d`
version = $(lsb_release -d)
echo $version
```
* local variables
```
HELLO=hello
function hello {
    local HELLO=world
    echo $HELLO
}
echo $HELLO
hello
echo $HELLO
```

# String 字符串
```
$'Hello\nWorld'  # 使用$可以把里面的字符转移，注意必须用单引号
```
* [大小写](https://stackoverflow.com/questions/2264428/how-to-convert-a-string-to-lower-case-in-bash): `${tring,,} ${string^^}`
* 判断是否包含字符串
```
if [[ ${version,,} == *"manjaro"* ]]; then
```

# [circle 循环](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-7.html)
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

for i in file1 file2 file3; do
    rm $i
done
```

# [judgement 判断](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-6.html#ss6.3)
```
if [ "foo" = "foo" ]; then  # 中括号旁边必须有空格,等号前后也必须有空格, 而且只有一个等号
else
fi

-f 'filename' 判断文件是否存在
-d 'directory' 判断文件夹是否存在
```

# ~~[shell scripts learning](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO.html)~~: **deprecated**

## [tables](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-11.html)
may be this title should be operations
* [String comparison operators](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-11.html#ss11.1)  
After reading this, I found there are too many error in this article (maybe it's my fault or not, anyway, this article didn't suit for me).
