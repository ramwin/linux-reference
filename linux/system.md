# 系统

* shell
    * 设置显示中文 `apt install language-pack-zh-hans`
    * pip安装   `export LC_ALL_C`
# 虚拟内存
* [Redis的Linux系统优化](https://cachecloud.github.io/2017/02/16/Redis的Linux系统优化/)
```
cat /proc/meminfo
echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
sysctl vm.overcommit_memory=1
```
* 创建虚拟内存
```
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" > /etc/fstab
```
如果偶尔不可以，要设置
```
sudo sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf
```

## 主机信息
### 主机名
查看: `hostname`
修改: 编辑 `/etc/hostname` 文件
