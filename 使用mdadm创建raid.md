# 使用mdadm创建raid

* [md](https://man7.org/linux/man-pages/man4/md.4.html)
* [mdadm](https://en.wikipedia.org/wiki/Mdadm)

[教程](https://cloudtuned.hashnode.dev/creating-a-raid-0-volume-in-ubuntu#heading-step-1-install-mdadm)

## 利用各个磁盘空间创建文件系统
* 创建文件设备占用各个磁盘空间
```
fallocate  --length 1G /home/wangx/raid5/a
fallocate  --length 1G /home/wangx/raid5/b
fallocate  --length 1G /home/wangx/raid5/c
fallocate  --length 1G /home/wangx/raid5/d

# 正式使用时使用各个磁盘的
fallocate  --length 1G /mnt/nvme1/a
fallocate  --length 1G /mnt/nvme2/b
fallocate  --length 1G /mnt/nvme3/c
fallocate  --length 1G /mnt/nvme4/d
```

* 把文件变成块设备
```
sudo losetup /dev/loop51 /home/wangx/raid5/a
sudo losetup /dev/loop52 /home/wangx/raid5/b
sudo losetup /dev/loop53 /home/wangx/raid5/c
sudo losetup /dev/loop54 /home/wangx/raid5/d
sudo losetup /dev/loop55 /home/wangx/raid5/e
```

* [使用mdadm创建磁盘](https://manned.org/mdadm)
```
sudo mdadm \
    --create --verbose /dev/md55 \
    --level=raid5 \
    --raid-devices=5 \
    /dev/loop51 \
    /dev/loop52 \
    /dev/loop53 \
    /dev/loop54 \
    /dev/loop55
```

* 创建文件系统
```
sudo mkfs.ext4 /dev/md55
sudo mkdir -p /media/md55/
sudo mount /dev/md55 /media/md55
```

## [增加磁盘](https://askubuntu.com/questions/1351183/how-to-add-a-new-drive-to-a-raid-mdadm-when-that-raid-is-encrypted-luks-an)
```
fallocate  --length 2G f_2g
sudo losetup /dev/loop56 /home/wangx/raid5/f_2g

# mount前, 5个1G的磁盘,变成了一个3.9G的磁盘
sudo umount /dev/md55
sudo mdadm --grow --raid-devices=6 /dev/md55 --add /dev/loop56
# mount后, 5个1G, 1个2G的磁盘, 变成了3.9G的磁盘
sudo mount /dev/md55 /media/md55
```

* [重新划分](https://www.itsfullofstars.de/2019/03/how-to-add-a-new-disk-to-raid5/)
```
sudo umount /dev/md55
sudo e2fsck -f /dev/md55
sudo resize2fs /dev/md55
sudo mount /dev/md55 /media/md55
# 重新mount后,变成了4.9的磁盘
```

## [损坏磁盘](https://blog.csdn.net/qq_44895681/article/details/105657604)
```
mdadm -D /dev/md55  # 查看磁盘状态, 当前6个active
sudo mdadm   /dev/md55 -f /dev/loop51 # 设置一个磁盘损坏, 还是4.9G文件正常
sudo mdadm -a /dev/md55 /dev/loop58  # 添加一个新的盘
sudo mdadm /dev/md55 --remove /dev/loop51  # 删除旧的盘
```

## 扩容
```
fallocate  --length 2G /home/wangx/raid5/59_2g
fallocate  --length 2G /home/wangx/raid5/60_2g
fallocate  --length 2G /home/wangx/raid5/61_2g
fallocate  --length 2G /home/wangx/raid5/62_2g

sudo losetup /dev/loop59 /home/wangx/raid5/59_2g
sudo losetup /dev/loop60 /home/wangx/raid5/60_2g
sudo losetup /dev/loop61 /home/wangx/raid5/61_2g
sudo losetup /dev/loop62 /home/wangx/raid5/62_2g
```

## 一个一个盘的损坏
```
sudo mdadm /dev/md55 -f /dev/loop52
```

## 删除坏盘
## [重新扩容后,容量只有5.9G](https://documentation.suse.com/sles/12-SP5/html/SLES-all/cha-raid-resize.html)
```
sudo mdadm --grow /dev/md55 -z max
sudo resize2fs /dev/md55 # 现在有了12G
```
