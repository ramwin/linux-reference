# 开机不登录也能用 SSH 和 DSH

```{contents}
```

## 问题

台式机（Manjaro/KDE）开机后停在登录界面，只要不在本机登录账户，
从外面 SSH 连不上，`dsh.ramwin.com`（DSH Web GUI）也打不开；
登录一次桌面后两者立刻恢复。

## 原因

两个服务看似都「开机自启」，实际都卡在「用户登录」这一步，但卡点不同：

| 服务 | 表面配置 | 真正卡点 |
|------|----------|----------|
| SSH | `sshd.service` 已 enabled，开机就监听 22 端口 | 整机没网：上网走 WiFi，而 WiFi 密码 `psk-flags=1` 存在 **KDE Wallet（用户密钥环）** 里，不登录桌面密钥环不解锁，NetworkManager 拿不到密码连不上 WiFi |
| DSH | KDE autostart 里有 `dsh-web.desktop` | autostart 本来就是「登录后才执行」；且 dsh web 跑在 `systemd --user` 里，`loginctl` 的 `Linger=no`，不登录连用户级 systemd 实例都不存在 |

排查命令（以后遇到同类问题可照抄）：

```bash
# 1. sshd 是不是系统服务、开机有没有起来
systemctl status sshd
journalctl -b -u sshd | head

# 2. WiFi 密码存在哪：psk-flags=1 是用户密钥环，0(或没有这行)是系统级
nmcli -t -f connection.permissions,802-11-wireless-security.psk-flags con show "你的WiFi名"

# 3. 用户服务是不是依赖登录
loginctl show-user $USER | grep -i linger
ls ~/.config/autostart/
```

## 修复

### 1. WiFi 密码改为系统级存储（解决 SSH）

```bash
sudo nmcli con mod "17-1701_5G" \
    802-11-wireless-security.psk-flags 0 \
    802-11-wireless-security.psk 'WiFi密码'
```

`psk-flags 0` 表示密码由 NetworkManager 存进
`/etc/NetworkManager/system-connections/*.nmconnection`（root 600），
开机后不需要任何用户登录就能连网。
等价图形操作：KDE 网络设置里编辑连接，重新填密码并勾选
「为所有用户存储密码（不加密）」。

### 2. lingering + systemd 用户服务（解决 DSH）

```bash
# 开机就拉起用户级 systemd 实例，不必等登录
sudo loginctl enable-linger wangx
```

新建 `~/.config/systemd/user/dsh-web-ensure.service`：

```ini
[Unit]
Description=DSH Web GUI 开机自启(幂等确保 --trusted-host dsh.ramwin.com)
After=default.target

[Service]
Type=oneshot
ExecStart=%h/bin/dsh-web-ensure.sh

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now dsh-web-ensure.service
```

原 KDE autostart 的 `dsh-web.desktop` 保留做兜底（ensure 脚本幂等，重复执行无副作用）。

### 3. 顺带修一个脚本坑

`dsh-web-public.sh` 里 `have_systemd()` 原来用
`systemctl --user is-system-running` 探测。lingering 开机自启时脚本在
`default.target` 事务内执行，此刻状态还是 `starting`，会误判「没有
systemd」退化到 `setsid` —— 而 setsid 起的进程会在 oneshot 单元退出时被
cgroup 回收，dsh web 刚起来就被杀。改为：

```bash
have_systemd() {
    command -v systemd-run >/dev/null 2>&1 || return 1
    systemctl --user list-units >/dev/null 2>&1   # 用户实例在(哪怕 starting)即可
}
```

## 验证

重启后在登录界面别动，直接从别的机器：

```bash
ssh wangx@<主机>
curl -sI https://dsh.ramwin.com   # 应返回 401(等 token) 而不是超时
```

本机确认 lingering 生效：

```bash
loginctl show-user wangx | grep Linger    # Linger=yes
systemctl --user is-enabled dsh-web-ensure.service   # enabled
```

## 版本记录

| 版本 | 日期 | 模型 | 说明 |
|------|------|------|------|
| v1 | 2026-11-05 | DeepSeek (DSH, k3-256k) | 初版：定位 WiFi 用户密钥环 + DSH 无 lingering 两个卡点并修复 |
