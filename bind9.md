# 刷新`dns`缓存
    sudo /etc/init.d/dns-clean start

# bind9服务
[官方教程](https://help.ubuntu.com/lts/serverguide/dns-configuration.html)
## 重启`bind9`服务
    sudo systemctl restart bind9.service    

# 用作 *缓存* 服务器
1. 编辑 `/etc/bind/named.conf.options` 文件
    forwarders {
        114.114.114.114;
        8.8.8.8
    }
2. 重启服务 `sudo systemctl restart bind9.service`  

# 用作 *Master* 服务器
1. 新建域名, 修改 `/etc/bind/named.conf.local` 文件
    zone "example.com" {
        type master;
        file "/etc/bind/db.example.com";
    }
2. 修改 `db.example.com` 文件 
