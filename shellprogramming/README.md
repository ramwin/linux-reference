**Xiang Wang @ 2018-05-04 19:52:09**

* [linux-totorial](../README.md)  

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

# [judgement](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-6.html#ss6.3)
```
if [ "foo" = "foo" ]; then  # 中括号旁边必须有空格,等号前后也必须有空格, 而且只有一个等号
else
fi
```

# [shell scripts learning](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO.html): **deprecated**

## [variables](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-5.html)
* example
```
STR="Hello World!"  # there is no space around the equals signal
echo $STR
OF=/var/my-backup-$(date +%Y%m%d).tgz
tar -cZf $OF /home/me/
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

## [tables](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-11.html)
may be this title should be operations
* [String comparison operators](http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO-11.html#ss11.1)  
After reading this, I found there are too many error in this article (maybe it's my fault or not, anyway, this article didn't suit for me).

# [Shell Scripting Tutorial](https://www.shellscript.sh/)
