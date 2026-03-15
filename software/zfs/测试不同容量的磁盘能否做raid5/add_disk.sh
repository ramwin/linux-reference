#!/bin/bash
# Xiang Wang(ramwin@qq.com)


fallocate -l 2G ./disk5.img

sudo losetup -f ./disk5.img

LOOPS=$(losetup -l | grep disk5.img | awk '{print $1}' | head -1)
sudo zpool addach testpool raidz1-0 $LOOPS

