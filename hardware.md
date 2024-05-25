# hardware 硬件
## cpu信息:
    cat /proc/cpuinfo | grep "processor" # 查看几线程
    cat /proc/cpuinfo | grep "physical id" # 查看物理CPU核数
## 鼠标设置速度
    xinput --set-prop "pointer:Logitech USB Receiver" "Device Accel Constant Deceleration" 2 # 设置鼠标速度
    xinput --set-prop "pointer:Logitech USB Receiver" "Device Accel Velocity Scaling" 1 # 设置鼠标加速度
## 鼠标加速度设置
    xset m 0 1
## 查看硬盘ID 
    blkid
* 重新挂载系统 `mount -o remount rw /   # 解决 read-only filesystem 问题`
* split 分割文件
    ```
    split -b 1900 test result   将文件分割成1900字节
    split -C 500 test result    将文件分割成每个最多500字节
    split -l 100 test result    将文件分割成每个100行
    split -d -l 10000 test result/block_    -d 用数字进行编号
    ```
* 移除硬件
    ```
    fdisk /dev/sdb 分区操作
    sudo apt-get install udisks
    udisks --umount /dev/sdb1
    udisks --detach /dev/sdb
    udiskctl power-off -b /dev/sdb
    ```
* 文件系统
    ```
    truncate -s 100KB <filepath>
    sudo mkfs.xfs <filepath>
    ```
* 修改卷标
    ```
    e2label /dev/sdb1/ UDISK
    ntfslabel /dev/sdb3/ LENOVO
    fatlabel /dev/sdb1 MI
    ```

