# Manjaro

## 新系统的操作
1. 安装显卡驱动: linux69-nvidia-470xx
linux69通过`uname -a`判断的
470xx通过[nvidia](https://www.nvidia.cn/drivers/unix/)判断的
2. 安装输入法
3. 安装常用软件
> sudo pacman --sync vim chromium redis postgresql supervisor nodejs npm gcc clang
4. vim配置
5. 密钥配置
7. 迁移github

## 我的配置

### 系统配置.config
* konsolerc [konsole终端配置](./konsolerc)
* kioslaverc 网络配置

> cd ~/.config  
ln -s /home/wangx/github/secret/config/kioslaverc ./

* kwinrc  [虚拟桌面配置](./kwinrc)
* fcitx5
    * config [输入法配置](./fcitx_config)
    ```
    cd ~/.config/fcitx5
    ln -s ~/github/linux-reference/manjaro/fcitx5_config ./config
    ```

* .local/share/knosole
    * [ramwin_konsole_profile.profile 主题设置](./ramwin_konsole_profile.profile)

### 服务配置
* crontab
```{literalinclude} ../crontab.sh
```

* postgresq
```
sudo su postgres
sudo mkdir /run/postgresql
sudo chown postgres:postgres /run/postgresql
cd ~

mkdir log
pg_ctl -D /var/lib/postgres/data/ -l log/pg_ctl.log start
```

## 输入法配置
* 最新安装输入法
直接安装`manjaro-asian-input-support`即可

* [manjaro下安装谷歌输入法]
```
sudo pacman -S fcitx-im
echo "export GTK_IM_MODULE=fcitx" >> ~/.xprofile
```

* [manjaro下安装输入法](https://www.jianshu.com/p/d7c8f29be182)  

```
sudo pacman-mirrors -c China  # 设置国内的软件源
sudo pacman -S fcitx-sogoupinyin
sudo pacman -S fcitx-im     # 全部安装
sudo pacman -S fcitx-configtool     # 图形化配置工具

vim ~/.xprofile
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=”@im=fcitx”
```


* [manjaro自动补全](https://forum.manjaro.org/t/git-missing-bash-completion/5939)
安装 bash-completion

* [manjaro安装mysql, maria](https://forum.manjaro.org/t/install-apache-mariadb-php-lamp-2016/1243)
```
sudo pacman -S mysql
sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
sudo systemctl enable mysqld
sudo systemctl start mysqld
```

## 蓝牙音频设置
蓝牙设置|软件                 |后端      |源  |效果
HSP     |SimpleScreenRecorder |PulseAudio| Monitor of Mi Bluetooth Headphones (karaoke)|不行
HSP     |SimpleScreenRecorder |PulseAudio| Mi Bluetooth Headphones (karaoke)|有声音但是不清晰

# 安装Linux manjaro
manjaro是一个比较好用的linux发行版. 软件比较新.

## 第一步: 下载系统iso文件
访问 https://manjaro.org/download/ 下载自己对应的CPU版本.
这里为了节约时间, 我已经下载好了

## 第二步: 使用软件, 把系统刻录到U盘
访问 https://docs.manjaro.org/burning-a-image-on-windows-using-etcher/ 有教程  
直接下载软件可以访问: https://etcher.balena.io/  

### 2.1 安装etcher

### 2.2 刻录到U盘

## 第三步: 重启电脑, 启动时按F2, F11, F12(不同系统按的不一样)通过U盘启动
