# SOFTWARE软件

```{toctree}
./nginx.md
```

## 网络类

### ufw
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
* 批量开启
```
ufw allow 19000:19999/tcp commment "批量开启测试端口"
```

## [airflow](../airflowtest/README.md)

## bat
和cat一样，但是输出会有格式化

## [celery](./celery/README.md)

## chromium
* 代理


    chromium-browser --proxy-server="socks5://127.0.0.1:1080" --host-resolver-rules="MAP * 0.0.0.0 , EXCLUDE localhost" &

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

    -scheme:chrome-extension 关闭插件的network

## convert
转化图片分辨率

```bash
sudo apt install imagemagick
convert image.png -resize 50% image2.png
```

## [crontab](./crontab.md)

## [daemon 守护进程](./daemon/README.md)

## ffmpeg
* 生成缩略图
```
ffmpegthumbnailer -i from.png  -o target.png -s500 -q10
```
* 转化视频和音频文件
```
ffmpeg -i django本地部署文档.mp4  -i 同步后的音频.aac  -strict -2 result.mkv
ffmpeg -i video.avi -i audio.mp3 -codec copy -shortest output.avi  # 用这个，速度更快。直接复制音频
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

## [prettier](https://prettier.io/docs/en/options.html)
### 配置
* trailingComma: "es5", 是否要在后面加分隔符逗号

## [proxychains](https://wiki.archlinux.org/index.php/Proxy_settings#Using_a_SOCKS_proxy)
```
    proxychains <program>
```

## rinetd: 用来端口转发

## rsync
用来同步数据的软件

    1. [官网](https://rsync.samba.org/documentation.html)
    2. [教程](https://everythinglinux.org/rsync/)

* 简介
有点: 快速(只上传改动部分, 压缩上传), 安全(ssh上传). 但是好像无法上传后加密

### 基础用法


    rsync -r --verbose <from_directory> <to_directory>/  # 这样会把from_directory 复制到 to_directory/from_directory
    rsync -r --verbose <from_directory>/ <to_directory>/  # 这样会把from_directory下的内容复制到 to_directory
    rsync -r --verbose version1/ version_latest/  # 先复制version1的
    rsync -r --verbose version2/ version_latest/  # 后复制version2的, 这样就是最新的了


### 参数 [官网](https://download.samba.org/pub/rsync/rsync.html)
* -u
    * --update: 如果receiver的文件比较新,就跳过
    * [ ] --inplace
    * --append: 把数据添加到短的文件上面, 之前的数据不动. 只能加,不能改
    * [ ] --append-verify
    * -n: 不操作，只看看
    * -v: 显示所有日志
    * --ignore-existing: 忽略存在的文件

### 示例
* 把文件上传到服务器  


    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_test/ localhost:/home/wangx/rsync_server/

    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_test2/ localhost:/home/wangx/rsync_server/


* 把服务的文件下载下来


    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_server/ localhost:/home/wangx/rsync_test/

    rsync --verbose  --progress --stats --compress --update --rsh=/bin/ssh \
          --recursive --times --perms --links \
          --exclude "*bak" --exclude "*~" \
          /home/wangx/rsync_server/ localhost:/home/wangx/rsync_test2/

* 复制文件夹


    rsync -vrn --ignore-existing from_directory/* to_directory  # 先看看
  

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

## [syncthing](https://docs.syncthing.net/intro/getting-started.html)
界面美观易用的同步软件
```
syncthing serve --gui-address=example.com:8384
```

## [SQLite](./sqlite/README.md)

## ssh
```
ssh -D 1080 <remote>  # 本地1080端口访问remote
```
* 使用ssh开启代理克隆github
[参考链接](https://randyfay.com/content/git-over-ssh-tunnel-through-firewall-or-vpn)
```
ssh -L3333:github.com:22 wangx@singapore.ramwin.com  # 把本地3333端口，通过singapore.ramwin.com去访问github.com
git clone ssh://git@localhost:3333/ninja-build/ninja.git  # 通过本地3333端口，访问singapore.ramwin.com来克隆github的项目
```
* 测试密码登录是否关闭
```shell
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no 
```
* SetEnv
登录后修改环境变量，一般服务器sshd只会允许设置`LC_*`
```shell
ssh -o "SetEnv LC_A=2"  # 这样服务器的 LC_A就是2了。 
```

## sshd
[配置文档](https://linux.die.net/man/5/sshd_config)

```
vim /etc/ssh/sshd_config
ClientAliveInterval: 60 #如果超过多少时间没有消息，就主动发送一个, 不要设置太小，不然ssh可能无法重启(因为发送频率太高了)
ClientAliveCountMax 3
PasswordAuthentication no  是否允许密码登录
```

## [supervisor](./software/supervisor.md)

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

## [terminal终端](./terminal.md)

## [tldr](https://github.com/tldr-pages/tldr)
too long don't read, 解决用man查看文档过于冗长的情况.
快速查看命令的文档
```
sudo pip3 install tldr
# 临时使用
tldr ls -s "http://tldr.ramwin.com/pages/"
# 永久设置ramwin源
export TLDR_PAGES_SOURCE_LOCATION="http://tldr.ramwin.com/pages/"
tldr ls
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

* [php](https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-in-ubuntu-16-04)
* [postfix](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-on-ubuntu-18-04)
* [rabbitmq](./rabbitmq/readme.md)

* [screen](./screen.md) *用来开启后台shell*
```
screen -list
screen -S sjtupt    # 创建新的screen
ctrl + A + D    # 关闭当前screen
screen -r sjtupt    # 还原之前的screen
ctrl + a 然后 esc 可以复制滚动 最后按esc退出
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

