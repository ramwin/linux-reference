# 网络工具
* 查看接口信息
    ifconfig  
* 流量
    more /proc/net/dev  # 配合 watch 就能实时查看了 查看当前  
    ntop    # 监控网络  
    sar -n DEV 1 10    # 1秒一次统计网速，统计10次  
    watch -n 1 "/sbin/ifconfig enp0s3 | grep bytes"
* 根据端口号查找进程
    lsof -i: 80
