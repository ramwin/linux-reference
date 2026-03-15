#!/bin/bash
# Xiang Wang(ramwin@qq.com)


set -ex
# 假设有4个盘构建raid5
fallocate -l 1G ./disk1.img
fallocate -l 1G ./disk2.img
fallocate -l 3G ./disk3.img
fallocate -l 4G ./disk4.img

for i in 1 2 3 4; do
    sudo losetup -f ./disk${i}.img
done

# 查看创建的loop设备
losetup -l | grep disk

LOOPS=$(losetup -l | grep disk | awk '{print $1}' | head -4)
sudo zpool create -f testpool raidz1 $LOOPS
