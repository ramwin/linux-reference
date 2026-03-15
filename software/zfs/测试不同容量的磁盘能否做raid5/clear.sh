#!/bin/bash
# Xiang Wang(ramwin@qq.com)


sudo zpool destroy testpool
LOOPS=$(losetup -l | grep disk | awk '{print $1}' | head -4)
for dev in $LOOPS; do
    sudo losetup -d $dev;
done
rm ./disk*.img
