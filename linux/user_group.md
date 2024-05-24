# 用户权限
* sudo免密码:
```
    echo "wangx ALL = (root) NOPASSWD:ALL" > /etc/sudoers.d/wangx
```

* 增加用户:   
```
    adduser git # 已经处理好了一下依赖
    mkdir /home/git
```
* 删除用户:   deluser git

* 添加组:
```
    sudo usermod -aG docker wang
    sudo usermod -aG sudo wang  // 允许wang执行sudo命令
```

* 查看uid, gid
```
$ whoami
wangx
$ id wangx
uid=1000(wangx) gid=1001(wangx) 组=1001(wangx),998(wheel),991(lp),3(sys),90(network),98(power),1000(autologin),965(docker)
```
