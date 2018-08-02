#### Xiang Wang @ 2017-06-22 13:53:03

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
