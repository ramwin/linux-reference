# shell
```{toctree}
./file_directory.md
```

## menu 目录
* [runoob 菜鸟网站](https://www.runoob.com/linux/linux-shell.html)
    * [ ] Shell 变量, 后面的字符串操作，数组，注释还没看
    * 传递参数
* [ ] [learning website](https://www.shellscript.sh/)
* [ ] [tutorials point](https://www.tutorialspoint.com/unix/unix-loop-control.htm)

* `set -ex`
报错的时候不再执行， 并且每次执行前输出执行的命令。 注意，这个无法获取到使用`&&`执行的报错

## [variables 变量](https://www.runoob.com/linux/linux-shell-variable.html)
* 赋值变量
```
STR="Hello World!"  # 等号两端不能有空格
echo $STR
OF=/var/my-backup-$(date +%Y%m%d).tgz
tar -cZf $OF /home/me/
## 把语句赋值给变量的两种方式
version=`lsb_release -d`
version = $(lsb_release -d)
echo $version
```

* 使用变量: 在变量名前面加美元符号(可以在外面加话括号)
```
your_name="qinjx"
echo $your_name
echo "hello ${your_name}'s friend"
```

* 只读变量: `readonly myUrl`, 这样后面赋值myUrl就会报错了
* 删除变量: `unset variable_name` 这时候没有美元符号

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

## parameter 参数
```
echo "当前脚本的文件名: $0"
echo "第一个参数 $1"
echo "一共 $#个参数"  # 不算如文件名
```

## String 字符串
```
$'Hello\nWorld'  # 使用$可以把里面的字符转移，注意必须用单引号
your_name='runoob'  # 单引号里面不能用变量和转义字符
str="Hello, you are \"$your_name\"!\n"  # 双引号里面才可以用变量和转义字符
echo $str
```

* 拼接字符串
```
greeting="hello, "$your_name" !"
greeting_1="hello, ${your_name} !"
```

* 字符串长度: `${#string}`


* [大小写](https://stackoverflow.com/questions/2264428/how-to-convert-a-string-to-lower-case-in-bash)
```
`${tring,,} ${string^^}`
```

* 判断是否包含字符串
```
if [[ ${version,,} == *"manjaro"* ]]; then
```

## [数组](https://www.runoob.com/linux/linux-shell-array.html)
```
list=($(cat test.txt))  # 读取文件，把所有单词变成一个数组, 注意不是所有行
echo ${list[0]}  # 第0行
echo ${list[*]}  # 所有行用@也可以。但是如果没有*和@就会变成输出第一个元素
array=(red green blue yellow magenta)  # 通过括号和空格来区分
```
* 获取数组长度
```
${#array[@]}
```
* 字符串切割变成数组
```
line=`cat input.txt`
array=($line)  # 变成了列表
```

## [circle 循环](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-7.html)
* 用 \` 可以执行命令
```shell
for i in `ls test`
do
    echo $i
    mv test/$i test/$i.jpg
done
```

```
for i in $( ls ); do  # 循环命令的结果列表
    if [ -d $i ]; then
        echo "directory: "
    elif [ $i = 'certainname' ]; then
    else
        echo "file: "
    fi
    echo item: $i
done

for i in file1 file2 file3; do  # 循环给定的列表
    rm $i
done

COUNTER=0
while [ $COUNTER -lt 10]; do
    echo The counter is $COUNTER
    let COUNTER=COUNTER+1
done

while [ $i -lt $array ]; do  # while循环列表
    echo "$i: ${array[$i]}"
    let i++
done
```

## judgement 判断
[runoob教程](https://www.runoob.com/linux/linux-shell-process-control.html)  
[测试](./ifelse.sh)  

### 格式
```shell
if condition
then
    command1
    command2
else
    command
fi
if [ "foo" = "foo" ]; then  # 中括号旁边必须有空格,等号前后也必须有空格, 而且只有一个等号
else
fi
if [[ "$HOME" = "/home/wangx" ]]; then  # 如果有变量， **需要使用双括号，或者在变量两边加引号**. 不然bash会把这个变量的value先放进去，然后再解析
fi
-f 'filename' 判断文件是否存在
-d 'directory' 判断文件夹是否存在
```

### 判断一个软件是否安装了
```shell
## 使用command来判断
for i in "cmatrix" "python2"; do
    programname="$i"
    result=`command -v $programname`
    echo "result: $result"
    if [ "$result" = "" ]; then
        echo "$programname 没有安装"
    else
        echo "$programname 已经安装"
    fi
done

for i in "nnn" "node"; do
    pacman -Q $i
    if [ $? = 0 ]; then
        echo "已经安装"
    else
        echo "安装 $i"
        pacman -S $i
    fi
done
```

### 判断一个仓库是否更新了
```shell
// ../script/判断仓库是否更新了.sh
function update()
{
    directoryname=`basename $(pwd)`
    current=`git log -1 --format="%H"`
    cache_file=/tmp/$directoryname
    if [ -f $cache_file ];
    then
        last=`cat $cache_file`
    else
        last=""
    fi
    if [[ $current = $last ]];
    then
        echo "一样的"
    else
        echo "代码仓变成了"$current
        echo $current > $cache_file
    fi
}
```

### 判断目录是否存在
```shell
if [ -d test_directory ]
then
    echo "test_directory存在"
fi
```

### 判断当前机器
```
a=`hostname`
if [ $a = 'windowsamd' ]
then
    echo '本地'
else
    echo '不是本地'
fi
```

## exceptions
```
echo "error"
exit 123
```

## 输入输出
* read

    read text;
    echo "您输入了: "$text

* select

    select name in red green blue yellow
    echo "You chose $name."


## built
* 某些时候你的命令比如cd被alias了, 用`built in cd`可以执行原始的cd命令

## 函数
注意，里面的CD会影响进程内部的PWD,但是不会影响执行后的PWD  
里面的变量定义后， 其他地方一般都能用。他是dynamic scope的
```
pre_step()
{
    echo "运行前"
    PWD
    cd ../
}
run()
{
    echo "run"
    PWD
}
post_step()
{
    echo "运行后"
    PWD
}
pre_step
run
post_step
```
