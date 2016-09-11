# cpu信息:
    cat /proc/cpuinfo | grep "processor" # 查看几线程
    cat /proc/cpuinfo | grep "physical id" # 查看物理CPU核数
# 鼠标设置速度
    xinput --set-prop "pointer:Logitech USB Receiver" "Device Accel Constant Deceleration" 2 # 设置鼠标速度
    xinput --set-prop "pointer:Logitech USB Receiver" "Device Accel Velocity Scaling" 1 # 设置鼠标加速度
# 鼠标加速度设置
    xset m 0 1
# 查看硬盘ID 
    blkid
