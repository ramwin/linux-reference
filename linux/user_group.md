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
```
