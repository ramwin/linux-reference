#!/bin/bash
# Xiang Wang(ramwin@qq.com)


mariadb-dump \
    -u wangx \
    --result-file employees3.sql \
    --lock-tables=False \
    --net-buffer-length=4K \
    employees employees
