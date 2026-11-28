# Manjaro

```{contents}
```

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
ln -s /home/user/github/secret/config/kioslaverc ./

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
```{literalinclude} ../script/crontab.sh
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

### 现状:Plasma 6 + Wayland + fcitx5

本机环境(2026-11 确认):

| 项 | 值 |
| --- | --- |
| 发行版 | Manjaro rolling |
| 桌面 | KDE Plasma 6.7.5 / Wayland(`XDG_SESSION_TYPE=wayland`、`XDG_CURRENT_DESKTOP=KDE`) |
| 输入法 | fcitx5 5.1.23(`fcitx5-chinese-addons` 5.1.15) |
| 启动方式 | KWin 虚拟键盘拉起:`kwinrc` 里 `InputMethod=/usr/share/applications/fcitx5-wayland-launcher.desktop`、`VirtualKeyboardEnabled=true` |
| 会话入口 | SDDM `SessionCommand=/usr/share/sddm/scripts/wayland-session` |

KWin 拉起 fcitx5 后,fcitx5 的 Wayland 输入法前端(`libwayland.so`)通过
`zwp_input_method` + text-input 协议工作,应用端不需要再挂 Gtk/Qt 的 im module。

### 提示「检测到设置了 GTK_IM_MODULE 和 QT_IM_MODULE 而且 Wayland 输入法前端正在正常工作」

这是 fcitx5 启动时打的一条**建议**,不是错误。原文:

> Detect GTK_IM_MODULE and QT_IM_MODULE being set and Wayland Input method frontend
> is working. It is recommended to unset GTK_IM_MODULE and QT_IM_MODULE and use
> Wayland input method frontend instead.

**原因链条**

1. 包 `manjaro-asian-input-support-fcitx5` 的 `/etc/profile.d/input-support.sh`
   在 KDE Wayland 分支(`set_im_env_kde_wayland`)里仍然导出
   `GTK_IM_MODULE=fcitx` / `QT_IM_MODULE=fcitx`,脚本注释写着
   "change from waylandui to classicui",即 Manjaro 保守地选了老路径。
2. `/usr/share/sddm/scripts/wayland-session` 在 `exec startplasma-wayland` 之前会
   `. /etc/profile` 和 `. ~/.profile`,于是这两个变量进入整个 Plasma 会话
   (`systemctl --user show-environment | grep IM_MODULE` 可见),被所有应用继承。
3. KWin 已经用虚拟键盘机制拉起 fcitx5 并启用了 Wayland 前端,两条输入路径同时在场,
   fcitx5 就提示你二选一。

**上游建议的 KDE Wayland 配置**(<https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland#KDE_Plasma>):

| 变量 | KDE Wayland 下 | 原因 |
| --- | --- | --- |
| `XMODIFIERS=@im=fcitx` | 保留 | XWayland(X11)应用走 XIM |
| `GTK_IM_MODULE` | **不要设** | Gtk3/Gtk4 用 text-input-v3 |
| `QT_IM_MODULE` | **不要设** | Qt6 用 text-input-v3,Qt5 用 KWin 支持的 text-input-v2 |
| `SDL_IM_MODULE=fcitx` | 保留 | XWayland 下的 SDL2 应用要靠它 |
| `INPUT_METHOD=fcitx` | 可有可无 | fcitx5 不读,少数老脚本会看 |

**落点:改家目录,别改 `/etc`**

`/etc/profile.d/input-support.sh` 属于包 `manjaro-asian-input-support-fcitx5`,
`pacman -Syu` 升级该包时会**直接覆盖**手工修改。本机就踩过一次:早先手工注释掉的
`export` 在 2026-10-30 升级到 `20251210-2` 之后又回来了,提示重新出现。
所以把 unset 放 `~/.profile`(`wayland-session` 会 source,包升级不影响):

```{literalinclude} ./profile
:language: sh
```

生效方式:**注销重新登录**(不用重启机器)。验证:

```bash
# 按 SDDM 的 source 顺序模拟,应只剩 XMODIFIERS / SDL_IM_MODULE / INPUT_METHOD
env -i HOME=$HOME USER=$USER SHELL=/bin/bash PATH=/usr/bin \
  XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE \
  bash -c '. /etc/profile; . $HOME/.profile; env | grep IM_MODULE'

# 新会话里再确认一次
systemctl --user show-environment | grep IM_MODULE
```

回滚:`rm ~/.profile` 后重新登录,即回到 Manjaro 默认(全局 im module)。

**个别应用中文输入失效时**

按需给那个应用单独加回旧路径,不要恢复全局设置:

```bash
mkdir -p ~/.local/share/applications
cp /usr/share/applications/xxx.desktop ~/.local/share/applications/
# 把 Exec=... 改成 Exec=env QT_IM_MODULE=fcitx /usr/bin/xxx %U
```

自带 Qt 库的应用(WPS、Anki、DaVinci Resolve 这类)往往得按上游 wiki 试
`QT_IM_MODULE=fcitx`、`QT_IM_MODULE=ibus` 或
`QT_QPA_PLATFORM=xcb QT_IM_MODULE=ibus`。

**两个坑**

* 不要在托盘菜单里点「重启」fcitx5:KWin 是通过文件描述符拉起它的,重启后拿不到
  原来的 socket,Wayland 前端会失效,只能注销重登。要改配置就去
  `kcmshell6 kcm_kwin_virtualkeyboard`(系统设置 → 键盘 → 虚拟键盘)看启动项,
  或者直接注销。
* 判断 Wayland 前端是否真在工作:看 `fcitx5-diagnose` 的 `Wayland` 段。若出现
  "Fcitx should be launched by KWin under KDE Wayland…",说明虚拟键盘没选 Fcitx 5。

### 历史:fcitx4 / X11 时代的写法

下面是旧记录,`export GTK_IM_MODULE` 之类的写法在 Plasma 6 Wayland 下**不要照抄**,
只留作 X11 会话参考。

* 直接安装 `manjaro-asian-input-support` 即可

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
