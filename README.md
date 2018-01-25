**Linux 知识快速查询**  
*这个是我平时遇到各种问题的时候记录下来的笔记.*

# 页面导航
* [command 常用口令](#常用口令)
* [software 软件](#软件)
* [regular expression 正则表达式学习](#正则表达式)
* [system 系统](./linux/system.md)
* [user & group 用户和组](./linux/user_group.md)
* [file 文本处理](./text.md)
* [markdown](./markdown.md)
* [bash, shell编程](./shellprogramming/README.md)

# 常用口令
* diff:
```
    -c:  把不同之处以及前3行和后3行显示出来。
    -r（recursively） 把子目录区别也比较出来
    -i :忽略大小写
    -w ：忽略空格和tab
    diff3: 比较3个文件的不同。
        diff3 MY-FILE COMMON-FILE YOUR-FILE。把两边的都和中间的文件比较
    diff -Nur originalfile newfile > patchfile:把旧文件和新的文件进行比较，生成文件的差，一次作为升级包
    patch -p1 < patchfile：把升级包应用于文件夹
    patch originalfile patchfile：把升级包应用于单个文件
```
* exit # 退出
* fdisk # 对磁盘进行分区
* find
    * `find . -path "*/migrations/*.py"` *查找文件*
    * `find ./ -type f -name "*.py" | xargs grep "verify_ssl"`
* notify-send
    * `notify-send 保护视力，休息一会`
* rename
    * `rename 's/group_public/group-public/g' *` *把当前目录下所有文件的group_public变成group-public*
* zentify
    * `zenity --info --text '保护视力，休息一会'

# 常用组合命令
* [批量修改文件名](https://stackoverflow.com/questions/6840332/rename-multiple-files-by-replacing-a-particular-pattern-in-the-filenames-using-a)
```shell
for f in *.png; do mv "$f" "`echo $f | sed s/file/ffff/`"; done
```

# 软件
* [database数据库](./database/README.md)
    * [mongodb](./mongodb.md)
    * [mysql](./mysql.md)
        * [Grant权限控制](./database/mysql_grant.md)
* [chromium]
    ```
    chromium-browser --proxy-server="socks5://127.0.0.1:1080" --host-resolver-rules="MAP * 0.0.0.0 , EXCLUDE localhost" &
    ```
* except  # 自动输入账号密码的工具，用来自动化脚本里面避免卡住
* [git](./git/README.md)
* [gnome](./gnome.md)
* [gpg](https://statistics.berkeley.edu/computing/encrypt)
    * 创建密钥 gpg --full-gen-key
    * 加密文件 gpg -e -r USERNAME <file>
    * 解密文件 gpg -d -o <target> <file>
* [nginx](./nginx.md)
* [redis](./redis/README.md)
* [阮一峰的oauth讲解](http://www.ruanyifeng.com/blog/2014/05/oauth_2_0.html)
* [screen](./screen.md) *用来开启后台shell*
    ```
    screen -list
    screen -S sjtupt    # 创建新的screen
    ctrl + A + D    # 关闭当前screen
    screen -r sjtupt    # 还原之前的screen
    ```
* smtp邮件服务器
    * [digitalocean.com教程](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-14-04)
    ```
    sudo apt install mailutils
    sudo apt install postfix
    修改 inet_interfaces = loopback-only 或者 localhost
    service postfix restart
    ```
    * [配置文档](http://blog.csdn.net/reage11/article/details/9295005)
* terminal终端
    * [快捷键参考](https://github.com/hokein/Wiki/wiki/Bash-Shell%E5%B8%B8%E7%94%A8%E5%BF%AB%E6%8D%B7%E9%94%AE)
    * 快捷键:
        * 移动: 左|下|上|右 ctrl+b | ctrl+n | ctrl+p | ctrl+f
        * 移动一个单词: alt+b | alt+f
        * 清屏: ctrl+l
* [vim](./vim.md) [tutorial教程](http://www.openvim.com/)

# 正则表达式
* [在线学习](https://regexone.com)
* [在线测试](https://regex101.com/#python)
* 规则:
    1. 基础 abc
    2. 数字 \d
    3. 通配符 .
    4. 任意选择 [abc] 匹配中间任何一个 [^abc] 反向匹配，不要出现abc任何一个
    5. [a-z] 匹配 a 到 z的小写字母
    6. 指定数量 \d{1,3}
    7. 至少有数字 \d+
    8. 可有可无一个 \d?
    9. \s 空白符(space)
    10. ^开头
    11. $结尾
    12. ()当作一个group ^(.*).pdf$ 所有的pdf文件的文件名
    13. | 代表或者 (cats|dogs)
    14. \w 数字或者字母
    15. \D \S \W 代表反过来
