#!/bin/sh
hostnamectl set-hostname $1
echo "wangx ALL = (root) NOPASSWD:ALL" > /etc/sudoers.d/wangx
ssh-keygen -q -t RSA -C "ramwin@qq.com"
curl 192.168.1.111:8000/Public/hosts > /etc/hosts
curl 192.168.1.111:8000/Public/ssh/config > /home/wangx/.ssh/config
# ssh-copy-id admin-node
# ssh-copy-id node1
# ssh-copy-id node2
# ssh-copy-id node3
# ssh-copy-id node4
# ssh-copy-id calamari2
