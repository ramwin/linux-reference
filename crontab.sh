#!/bin/bash
# Xiang Wang(ramwin@qq.com)


/home/wangx/github/secret/shadowsocks/run_sslocal.sh \
& syncthing \
& (cd /home/wangx/github/linux-reference/ && sh run_server.sh) \
& (cd /home/wangx/github/python-reference/ && sh run_server.sh) \
& (cd /home/wangx/github/django-reference/ && sh run_server.sh)
