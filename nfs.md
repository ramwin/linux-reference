# NFS

[参考链接](https://help.ubuntu.com/lts/serverguide/network-file-system.html)

## 安装
## 前提
* 访问[链接](https://m.do.co/c/4c025e859876)注册用户并购买两台服务器
    * www.ramwin.com(client)    # 如果没有域名可以改成IP地址
    * dns.ramwin.com(server)

## 安装
**server:**  

    apt install nfs-kernel-server  
    mkdir /remote_dir  
    echo "test txt" > /remote_dir/test
    echo "/remote_dir *(rw,sync,no_subtree_check)" > /etc/exports
    systemctl start nfs-kernel-server.service

**client:**

    mkdir /remote_dir
    mount dns.ramwin.com:/remote_dir /remote_dir
    cat /remote_dir/test

    # 或者编辑 /etc/fstab
    ip:/nfsexport /mnt/nfs nfs defaults 0 0
