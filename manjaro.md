**Xiang Wang @ 2018-10-09 22:35:33**

## Manjaro
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

### 蓝牙音频设置
蓝牙设置|软件                 |后端      |源  |效果
HSP     |SimpleScreenRecorder |PulseAudio| Monitor of Mi Bluetooth Headphones (karaoke)|不行
HSP     |SimpleScreenRecorder |PulseAudio| Mi Bluetooth Headphones (karaoke)|有声音但是不清晰
