# 举例
[参考](http://blog.csdn.net/jemmy858585/article/details/4724029)
* manjaro
```
/dev/nvme0n1p6 /run/media/wangx/d ntfs defaults,rw,user 0,0
/dev/nvme0n1p2 /run/media/wangx/samsung ntfs3 rw,nosuid,nodev,relatime,uid=1000,gid=1000,iocharset=utf8,uhelper=udisks2 0 0
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
UUID=ef7f1ec9-c915-44cb-bc2f-12a72e6bdc94 /               ext4    errors=remount-ro 0       1
# /boot/efi was on /dev/sdb1 during installation
UUID=29ED-B39C  /boot/efi       vfat    umask=0077      0       1
# swap was on /dev/sdb3 during installation
UUID=fe7d78cc-9920-4758-bccd-9e694fe79c6b none            swap    sw              0       0

UUID=DA1CA8A71CA8805D /home/wangx/PUTAO ntfs defaults,rw,user 0 0
```
