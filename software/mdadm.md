# mdadm

* 创建raid
```
# 这个尺寸是2TB(不是2TiB)对应的最大kb（扣除了一百多M的metadata)
sudo mdadm --create /dev/md1 --level=1 --raid-devices=2 --size=1952992256 /dev/sdc4 /dev/sde3

sudo mdadm --detail --scan >> /etc/mdadm.conf  # 不同系统不一样

sudo mkfs.ext4 -L RAID1-2TB /dev/md1
```


