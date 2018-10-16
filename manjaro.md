**Xiang Wang @ 2018-10-09 22:35:33**

## Manjaro
* [manjaro下安装输入法](https://www.jianshu.com/p/d7c8f29be182)
```
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
