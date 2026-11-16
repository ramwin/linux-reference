# fstab

```{contents}
```

```{note}
本仓是**公开仓库**（GitHub public + 站点匿名可读）。下面的 UUID、挂载点、
用户名路径一律是**占位符**，不要写真实值——真实的磁盘布局属于私人机器信息，
记在自己的私有仓里。新增内容前先看 [CLAUDE.md](../CLAUDE.md) 的「公开仓红线」。
```

[参考](http://blog.csdn.net/jemmy858585/article/details/4724029)

1. `sudo blkid /dev/md5` 看UUID
2. 配置挂载点
```
UUID=11111111-1111-1111-1111-111111111111  /mnt/raid1 ext4 defaults,nofail 0 2
UUID=22222222-2222-2222-2222-222222222222  /mnt/raid5 ext4 defaults,nofail 0 2
```

## manjaro配置
```
/dev/nvme0n1p6 /run/media/user/d ntfs defaults,rw,user 0,0
/dev/nvme0n1p2 /run/media/user/samsung ntfs3 rw,nosuid,nodev,relatime,uid=1000,gid=1000,iocharset=utf8,uhelper=udisks2 0 0
```

* 文档
```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sdb2 during installation
UUID=33333333-3333-3333-3333-333333333333 /               ext4    errors=remount-ro 0       1
# /boot/efi was on /dev/sdb1 during installation
UUID=AAAA-BBBB  /boot/efi       vfat    umask=0077      0       1
# swap was on /dev/sdb3 during installation
UUID=44444444-4444-4444-4444-444444444444 none            swap    sw              0       0

UUID=CCCCDDDDCCCCDDDD /home/user/data ntfs defaults,rw,user 0 0
```

## 要点

- 用 `UUID=` 而不是 `/dev/sdX`：盘序变化不会挂错，热插拔也稳定。
- 数据盘加 `nofail`：盘掉线时不阻塞开机进系统。
- 纯数据盘（尤其大容量）可以 `mkfs.ext4 -m 1` 把 root 保留块从 5% 降到 1%，
  1.8T 的盘能多出约 74G 可用空间；系统盘不要这么干。
- 改完 fstab 先 `sudo mount -a` 试挂，再 `sudo findmnt --verify` 校验语法，
  最后 `sudo systemctl daemon-reload` 让 systemd 重读，别等下次重启才发现挂不上。
- 目录属主要在**挂载之后**再 `chown`：先改后挂，改的是被隐藏的底层目录，
  挂载后看到的还是 root 属主，普通用户写不进去。
