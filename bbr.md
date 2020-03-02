**Xiang Wang @ 2020-02-27 19:31:57**

BBR是google的TCP阻塞控制算法，可以最大程度的利用带宽，提升网络传输速率。

Linux kernel 4.9 及以上已支持 tcp_bbr

1.查看系统内核版本：

uname -r

看内核版本是否大于等于4.9，否则要升级内核，或者安装bbr。

2.开启BBR：

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf

echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

3.保存生效：

sysctl -p

4.检查BBR是否启用：

sysctl net.ipv4.tcp_available_congestion_control

返回值一般为：net.ipv4.tcp_available_congestion_control = reno cubic bbr

sysctl net.ipv4.tcp_congestion_control

返回值一般为：net.ipv4.tcp_congestion_control = bbr

sysctl net.core.default_qdisc

返回值一般为：net.core.default_qdisc = fq

lsmod | grep bbr

返回值有 tcp_bbr 模块则BBR已启动：

tcp_bbr 20480 10

作者：Mr_Bluyee
链接：https://www.jianshu.com/p/98c21990ed23
来源：简书
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
