**Xiang Wang @ 2015-11-18**  

# menu
* [system 系统 优化](./linux/system.md)
* [user & group 用户和组](./linux/user_group.md)
* [markdown](./markdown.md)
* [shell编程](./shellprogramming/README.md)
* [linux命令搜索网站](https://wangchujiang.com/linux-command/)

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
* curl
    * post请求: `curl -d 'name=value' <url>`
    * 发送文件: `curl -F 'data=@path/to/local/file' <url>`
* dd:
复制文件
    * [测试磁盘速度](https://www.shellhacks.com/disk-speed-test-read-write-hdd-ssd-perfomance-linux/)
    ```
    $ sync; dd if=/dev/zero of=tempfile bs=1M count=1024; sync  # 测试写入速度
    $ dd if=tempfile of=/dev/null bs=1M count=1024  # 测试读取速度
    ```
* dig  
用drill
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
* [drill](https://wiki.archlinux.org/index.php/Domain_name_resolution#Lookup_utilities)
```
dril @dnsserver 
```
* du
```
du -h -d 1 | sort -h  # 输出文件夹大小并按照尺寸排序
```
* echo: 输出文字
```
echo -e "\e[x;y;zm我要的文字\e[0m"
x,y,z代表了属性
颜色: 黑色=30，红色=31，绿色=32，黄色=33，蓝色=34，洋红=35，青色=36，白色=37
背景色: 黑色=40，红色=41，绿色=42，黄色=43，蓝色=44，洋红=45，青色=46，白色=47
其他效果: 0 关闭所有属性、1 设置高亮度（加粗）、4 下划线、5 闪烁、7 反显、8 消隐
```

* exit: 退出
* fdisk: 对磁盘进行分区
    * `fdisk -l`: 查看电脑上有多少硬盘
* find
    * `find . -path "*/migrations/*.py"` *查找文件*
    * `find ./ -type f -name "*.py" | xargs grep "verify_ssl"`
    * `find -name '*.py' -not -path './EVN/*`
    * `find . -iregex '.*.\(py\|html\)'`
* grep
`grep string <file>`: 从file中找到文字
* hddtemp: 查看硬盘的温度
* iconv: 转化文件编码 `iconv -f GBK -t utf-8//IGNORE originfile -o target`
* iftop:
```
iftop -i ens3 -P 查看某个网卡的网络进出情况
```
* ip: 查看网卡端口 `ip link show`
* less `<filename>`: 打开文件（一点点看）,用于查看大文件
* `lshw -c disk`: "显示硬盘信息"
* notify-send
    * `notify-send 保护视力，休息一会`
* rar
    * `rar a -v1024k netease.rar netease`: 把netease创建成多个压缩文件，最大1024k
* rename
    * `rename 's/group_public/group-public/g' *` *把当前目录下所有文件的group_public变成group-public*
    * `rename 's/(\d+).png/banner-\1.png/g' *` *替换目录下的所有banner*
    * `rename -v '20190415' '2019-04-15' *.json`
* ## sed
    * `sed -i 's/pattern/replace/g' <filename>` *把文件内满足pattern的替换成replace*
    * `sed -i 's/\r$//g' <filename>` *删除文件的`\r`*  
    * `sed -r 's/useless([0-2]{2,})replace/\1/' test.txt` *替换某段字符并提取出里面的信息*
* ## seq
```
seq 10  # 输入1到10
seq 10 | xargs -i command  # 执行一个代码10次
seq 10 | xargs -i echo "{}123"  # 执行一个代码10次
```
* sort:
    * 按照文件尺寸来排序: `sort -h`
    * 直接按照一行的文字来排序: `sort -n`
* su:
```
su -s /bin/bash www-data  # 使用www-data来执行bash命令
```
* swap
```
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab
echo "vm.swappiness=10" >> /etc/sysctl.conf
```
* tar
```
tar -zcvf github.tar.gz github
tar -c -f project.tar --exclude=".git*" project/
```
* tcpdump 监控网络数据 `tcpdump -l -i eth0 -w - src or dst port 3306 | strings`
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
## celery  
[celery/README.md](./celery/README.md)

## chromium
* 代理
    ```
    chromium-browser --proxy-server="socks5://127.0.0.1:1080" --host-resolver-rules="MAP * 0.0.0.0 , EXCLUDE localhost" &
    ```
* cvim
一款优秀的vim插件, 为了兼容tower的网站，需要加以下配置
```
let searchlimit = 4
let blacklists = ["https://ecs.console.aliyun.com/*"]
let hintcharacters = "abcdefghijklmnpqrstuvwxyz"
showTodoRest -> {{
  var doms = document.getElementsByClassName("todo-rest")
  for (var i=0; i<doms.length; i++) {
    var dom = doms[i];
    dom.setAttribute("tabindex", true);

  }
}}
call showTodoRest
```
* 调试
```
-scheme:chrome-extension 关闭插件的network
```

## [crontab](./crontab.md)
定时任务脚本

## [daemon 守护进程](./daemon/README.md)

## ffmpeg
* 生成缩略图
```
ffmpegthumbnailer -i from.png  -o target.png -s500 -q10
```
* 转化视频和音频文件
```
ffmpeg -i django本地部署文档.mp4  -i 同步后的音频.aac  -strict -2 result.mkv
ffmpeg -i result.mkv  -vcodec copy -acodec copy -ss 00:01:02.7  ./result_cut.mkv  # 截取视频
ffmpeg -ss 00:01:06.4 -i result.mkv  -vcodec copy -acodec copy  ./result_cut.mkv  # 这个截取会多一点视频，但是避免出现黑屏
```

## [git](./git.md)  
一款优秀的版本管理工具, 不仅是代码管理, 更是版本管理. 我觉得不仅写代码的人要学会用这个, 所有的办公人员都应该学会

## [language-pack-zh-hans](https://www.jianshu.com/p/2ae564a1f131)  
安装中文支持
```
apt install language-pack-zh-hans
LANG="zh_CN.UTF-8"
```

## [manjaro](./manjaro.md)
## [mongodb](./mongodb.md)
## [mysql 数据库](./mysql/README.md)
* [Grant权限控制](./database/mysql_grant.md)
* [mysqldump](./mysql/README.md)

## nnn
文件管理
```
pacman -S nnn
```

## pacman
```
pacman -Syy  # 更新数据库
pacman -Syu  # 安装最新软件
pacman -S package_name1 package_name2
pacman -R package_name  # 卸载某个软件
sudo pacman -Rns $(pacman -Qtdq)  # 卸载不需要的包
```

## [pandoc](https://pandoc.org/)
把各种markup格式的格式转化成其他各种文档格式

## postgresql
* 教程
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

## [prettier](https://prettier.io/docs/en/options.html)
### 配置
* trailingComma: "es5", 是否要在后面加分隔符逗号

## [proxychains](https://wiki.archlinux.org/index.php/Proxy_settings#Using_a_SOCKS_proxy)
```
    proxychains <program>
```

## [redis](./redis.md)
## rinetd: 用来端口转发

## rsync
用来同步数据的软件
    1. [官网](https://rsync.samba.org/documentation.html)
    2. [教程](https://everythinglinux.org/rsync/)

* 简介
有点: 快速(只上传改动部分, 压缩上传), 安全(ssh上传). 但是好像无法上传后加密

* ### 参数 [官网](https://download.samba.org/pub/rsync/rsync.html)
    * -u
        * --update: 如果receiver的文件比较新,就跳过
        * [ ] --inplace
        * --append: 把数据添加到短的文件上面, 之前的数据不动. 只能加,不能改
        * [ ] --append-verify

* ### 示例
    * 把文件上传到服务器  
    ```
    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_test/ localhost:/home/wangx/rsync_server/

    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_test2/ localhost:/home/wangx/rsync_server/
    ```
    * 把服务的文件下载下来
    ```
    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_server/ localhost:/home/wangx/rsync_test/

    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_server/ localhost:/home/wangx/rsync_test2/
    ```

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
        wget http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin 330kb/s(宿舍，长城宽带，晚上11点)
        ```
        * [digitalocean](http://speedtest-sfo1.digitalocean.com/)
        * [服务器上测试中国各地区的网址](https://github.com/oooldking/script)
        ```
        wget https://raw.githubusercontent.com/oooldking/script/master/superspeed.sh
        sh superspeed.sh
        ```
        * [多个地点ping服务器](http://ping.chinaz.com/)

## samba  
用来安装共享文件夹，方便多台电脑共享文件
[安装部署教程](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-samba-share-for-a-small-organization-on-ubuntu-16-04)

## [SQLite](./sqlite/README.md)

## sshd
[配置文档](https://linux.die.net/man/5/sshd_config)

```
vim /etc/ssh/sshd_config
ClientAliveInterval: 10 #如果超过多少时间没有消息，就主动发送一个
ClientAliveCountMax 3
```

## [supervisor](http://supervisord.org/index.html)
守护进程设置
* [centos安装](https://www.php.cn/linux-413808.html)
* 运行supervisor
    * supervisorctl
    ```
    supervisorctl stop <name>  停止一个进程
    ```
* [配置文件](http://supervisord.org/configuration.html#program-x-section-example)
```
[program:redis]
user=dev
directory = /var/www/project
command=gunicorn project.wsgi -c deploy/gunicorn.conf.py
autostart=true
autorestart=true
redirect_stderr=false
stdout_logfile=/a/path
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=10
stdout_capture_maxbytes=1MB
stdout_events_enabled=false
stderr_logfile=/a/path
stderr_logfile_maxbytes=1MB
stderr_logfile_backups=10
stderr_capture_maxbytes=1MB
stderr_events_enabled=false
```
* [日志](http://supervisord.org/logging.html)

## tsocks 让应用启动的时候走代理
```
# 配置tsocks
vim /etc/tsocks.conf
server = 127.0.0.1
server_port = 1080
server_type = 5
# 启动
tsocks firefox
```

## terminal终端
* [快捷键参考](https://github.com/hokein/Wiki/wiki/Bash-Shell%E5%B8%B8%E7%94%A8%E5%BF%AB%E6%8D%B7%E9%94%AE) [快捷键参考2](https://www.cnblogs.com/zhouj-happy/p/11375658.html)
* 删除快捷键:
    alt+d: 删除光标右边的单词
    ctrl+w: 删除当前光标左边的单词
* 移动
    * 移动: 左|下|上|右 ctrl+b | ctrl+n | ctrl+p | ctrl+f
    * 移动一个单词: alt+b | alt+f
* 快捷键:
    * 清屏: ctrl+l

## ufw
* 打开/关闭ufw
```
ufw enable/disable
```
* 开放某个端口
```
ufw allow 22 comment "允许ssh登录"
```
* 查看当前状态
```
ufw status numbered
```
* 允许某个host通过某个端口
```
ufw allow from 172.16.15.66 to any port 6379
```

## [vim](./vim.md)
[交互式的tutorial教程](http://www.openvim.com/)
* [multiple-cursor](https://github.com/terryma/vim-multiple-cursors#quick-start)
    `:MultipleCursorsFind <regrexmatch>`

## vscode
```
.vscode/settings.json
{
  "files.exclude": {
    "*.wxss": true,
    "*/*.wxss": true
  }
}
```


## other
* alarm-clock-applet 闹钟
* except: 自动输入账号密码的工具，用来自动化脚本里面避免卡住
* [gnome](./gnome.md)
* [gpg](https://statistics.berkeley.edu/computing/encrypt)
    * 创建密钥 gpg --full-gen-key
    * 加密文件 gpg -e -r USERNAME <file>  生成file.gpg文件
    * 解密文件 gpg -d -o <新的文件名> <加密的gpg文件>
* iotop: `查看磁盘当前读写速度`
* kazam 录屏软件
此外还有 greenrecorder, vokoscreen, simplescreenrecorder(manjaro上好用)
* [nginx](./nginx.md)
    * [Download](http://nginx.org/)
    * [Tutorial in Didital Ocean](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-18-04)
    * [Compile and Configure](http://nginx.org/en/docs/configure.html)

* [php](https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-in-ubuntu-16-04)
* [postfix](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-on-ubuntu-18-04)
* [rabbitmq](./rabbitmq/README.md)

* [screen](./screen.md) *用来开启后台shell*
```
screen -list
screen -S sjtupt    # 创建新的screen
ctrl + A + D    # 关闭当前screen
screen -r sjtupt    # 还原之前的screen
```
* simplescreenrecorder *录屏软件*
* smtp邮件服务器  **新版参考postfix**
    * [digitalocean.com教程](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-18-04)
    ```
    sudo apt install mailutils
    sudo apt install postfix
    修改 inet_interfaces = loopback-only 或者 localhost
    service postfix restart
    ```
    * [配置文档](http://blog.csdn.net/reage11/article/details/9295005)
* [阮一峰的oauth讲解](http://www.ruanyifeng.com/blog/2014/05/oauth_2_0.html)
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

