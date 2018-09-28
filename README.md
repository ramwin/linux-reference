**Xiang Wang @ 2015-11-18**  

# menu
* [system 系统 优化](./linux/system.md)
* [user & group 用户和组](./linux/user_group.md)
* [markdown](./markdown.md)
* [shell编程](./shellprogramming/README.md)

# command
* [ ] awk
```
awk '{print $1}' filename
```
* chardet3 检测文件编码
* cp:
复制一个文件或者文件夹  
    * 不会删除原有的文件
    * -i: 如果遇到重复的文件，就进行询问
    * -r: 把文件夹内部的所有文件都复制出来。会覆盖掉重名文件
    * -u: 把文件夹内部的所有文件都复制出来，保留新的那个文件
    * -v: 显示复制的过程
* dd:
复制文件
    * [测试磁盘速度](https://www.shellhacks.com/disk-speed-test-read-write-hdd-ssd-perfomance-linux/)
    ```
    $ sync; dd if=/dev/zero of=tempfile bs=1M count=1024; sync  # 测试写入速度
    $ dd if=tempfile of=/dev/null bs=1M count=1024  # 测试读取速度
    ```
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
* du
```
du -h -d 1 | sort -h  # 输出文件夹大小并按照尺寸排序
```
* exit: 退出
* fdisk: 对磁盘进行分区
    * `fdisk -l`: 查看电脑上有多少硬盘
* find
    * `find . -path "*/migrations/*.py"` *查找文件*
    * `find ./ -type f -name "*.py" | xargs grep "verify_ssl"`
* grep
`grep string <file>`: 从file中找到文字
* hddtemp: 查看硬盘的温度
* iconv: 转化文件编码 `iconv -f GBK -t utf-8 originfile -o target`
* less `<filename>`: 打开文件（一点点看）,用于查看大文件
* notify-send
    * `notify-send 保护视力，休息一会`
* rar
    * `rar a -v1024k netease.rar netease`: 把netease创建成多个压缩文件，最大1024k
* rename
    * `rename 's/group_public/group-public/g' *` *把当前目录下所有文件的group_public变成group-public*
    * `rename 's/(\d+).png/banner-\1.png/g' *` *替换目录下的所有banner*
* ## sed
    * `sed -i 's/pattern/replace/g' <filename>` *把文件内满足pattern的替换成replace*
    * `sed -i 's/\r$//g' <filename>` *删除文件的`\r`*  
    * `sed -r 's/useless([0-2]{2,})replace/\1/' test.txt` *替换某段字符并提取出里面的信息*
* sort:
    * 按照文件尺寸来排序: `sort -h`
    * 直接按照一行的文字来排序: `sort -n`
* [ ] tee  
* tidy
> Tidy is a console application which corrects and cleans up HTML and XML
documents by fixing markup errors and upgrading legacy code to modern
standards. Tidy is a product of the World Wide Web Consortium and the HTML
Tidy Advocacy Community Group.
* timedatectl
    `timedatectl set-local-rtc 1`: 关闭使用utc时间
* tr
    * [参考网站](http://www.linfo.org/tr.html)
    * `tr -d '{{input_characters}}'` *删除文件内指定的字符串*
* unrar
    `unrar x file.part01.rar` 解压文件，会自动把多个文件一起解压
    `unrar e netease.part01.rar  <director>`  解压文件到指定路径
* unzip
    * `unzip -O gbk filename.zip`: 处理windows的zip文件
    * `unzip -O gbk -l filename.zip`: 只看看，不解压
* wc
    * 按照文件的行数来排序: `ls | xargs wc -l | sort -nr`
* zentify
    * `zenity --info --text '保护视力，休息一会'
* zip 压缩文件 zip -r target.zip sourcedirectory/

# software 软件
## alarm-clock-applet 闹钟
## [celery](http://docs.celeryproject.org/en/latest/index.html)
`celery -A tasks worker --loglevel=info`
## [git](./git.md)  
    * build your git server
    ```
    [root:~/] sudo adduser git
    [git:~/] git init --bare repository.git
    [root:~/] vim /etc/passwd  # change git line to 'git:x:1001:1001:,,,:/home/git:/bin/bash'
    ```
## kazam 录屏软件
此外还有 greenrecorder, vokoscreen
## [mongodb](./mongodb.md)
## [mysql 数据库](./mysql.md)
* [Grant权限控制](./database/mysql_grant.md)
* [mysqldump](./mysql.md)

## shadowsocks
* 各个服务器的测速
    * [linode](https://www.linode.com/speedtest)
    ```
    wget http://speedtest.newark.linode.com/100MB-newark.bin 23kb/s(宿舍，长城宽带，凌晨1点)
    wget http://speedtest.atlanta.linode.com/100MB-atlanta.bin
    wget http://speedtest.dallas.linode.com/100MB-dallas.bin
    wget http://speedtest.fremont.linode.com/100MB-fremont.bin
    wget http://speedtest.frankfurt.linode.com/100MB-frankfurt.bin
    wget http://speedtest.london.linode.com/100MB-london.bin
    wget http://speedtest.singapore.linode.com/100MB-singapore.bin
    wget http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin
    ```
    * [digitalocean](http://speedtest-sfo1.digitalocean.com/)
    * [服务器上测试中国各地区的网址](https://github.com/oooldking/script)
    ```
    wget https://raw.githubusercontent.com/oooldking/script/master/superspeed.sh
    sh superspeed.sh
    ```
    * [多个地点ping服务器](http://ping.chinaz.com/)

## [SQLite](http://www.sqlitetutorial.net/)
* [dump 备份数据库](http://www.sqlitetutorial.net/sqlite-dump/)
    ```
    .output backup.sql
    .dump
    .exit

    或者
    .output test.txt
    select * from table;
    ```

* read 还原数据库
    ```
    sqlite3 test.db
    .read <filename>
    .import 文件名 表名
    ```

## other
* [chromium]
    ```
    chromium-browser --proxy-server="socks5://127.0.0.1:1080" --host-resolver-rules="MAP * 0.0.0.0 , EXCLUDE localhost" &
    ```
* except: 自动输入账号密码的工具，用来自动化脚本里面避免卡住
* [gnome](./gnome.md)
* [gpg](https://statistics.berkeley.edu/computing/encrypt)
    * 创建密钥 gpg --full-gen-key
    * 加密文件 gpg -e -r USERNAME <file>  生成file.gpg文件
    * 解密文件 gpg -d -o <新的文件名> <加密的gpg文件>
* iotop: `查看磁盘当前读写速度`
* ## postgresql
    1. [install and use postgresql ](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-ubuntu-16-04)  [Getting Started](https://www.postgresql.org/docs/10/static/tutorial-start.html)
    ```
    sudo apt install postgresql postgresql-contrib
    sudo -i -u postgres
    psql
    sudo -u postgres psql
    createuser --interactive

    createdb [<databasename>] default name is the username
    dropdb <databasename>

    psql <databasename>
    ```
    2. The SQL Language
        1. Introduction
        ```
        cd ..../src/tutorial
        make
        cd ..../toturial
        psql -s mydb
        mydb=> \i basics.sql
        ```
    3. Advanced Features
        2. Views
        ```
        CREATE VIEW myview AS SELECT city, temp_lo, temp_hi, location FROM weather, cities WHERE city = name;
        SELECT * FROM myview;
        ```

    * [current learning progress](https://www.postgresql.org/docs/10/static/tutorial.html)

* [nginx](./nginx.md)
    * [Download](http://nginx.org/)
    * [Tutorial in Didital Ocean](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-18-04)
    * [Compile and Configure](http://nginx.org/en/docs/configure.html)
* [php](https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-in-ubuntu-16-04)
* [rabbitmq](https://www.rabbitmq.com/)
    * [Tutorials](https://www.rabbitmq.com/getstarted.html)
    * change password  
    ````
    rabbitmqctl change_password <username> <password>  # changepassword
    rabbitmqctl set_permissions -p / rabbit ".*" ".*" ".*"  # allow access
    ````
* ## [redis](./redis.md)
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
    * 删除快捷键:
        alt+d: 删除光标右边的单词
        ctrl+w: 删除当前光标左边的单词
    * 快捷键:
        * 移动: 左|下|上|右 ctrl+b | ctrl+n | ctrl+p | ctrl+f
        * 移动一个单词: alt+b | alt+f
        * 清屏: ctrl+l
* ## [vim](./vim.md) [tutorial教程](http://www.openvim.com/)
    * [multiple-cursor](https://github.com/terryma/vim-multiple-cursors#quick-start)
        `:MultipleCursorsFind <regrexmatch>`
* 7z

# hardware 硬件
* 重新挂载系统 `mount -o remount rw /   # 解决 read-only filesystem 问题`
* split 分割文件
    ```
    split -b 1900 test result   将文件分割成1900字节
    split -C 500 test result    将文件分割成每个最多500字节
    split -l 100 test result    将文件分割成每个100行
    split -d -l 10000 test result/block_    -d 用数字进行编号
    ```
* 移除硬件
    ```
    fdisk /dev/sdb 分区操作
    sudo apt-get install udisks
    udisks --umount /dev/sdb1
    udisks --detach /dev/sdb
    udiskctl power-off -b /dev/sdb
    ```
* 文件系统
    ```
    truncate -s 100KB <filepath>
    sudo mkfs.xfs <filepath>
    ```
* 修改卷标
    ```
    e2label /dev/sdb1/ UDISK
    ntfslabel /dev/sdb3/ LENOVO
    fatlabel /dev/sdb1 MI
    ```

# regular expression
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
    16. (?!abc) 不能出现abc
