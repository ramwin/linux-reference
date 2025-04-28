#!/bin/bash

mysqldump   \
    -u wangx \
    --set-gtid-purged=OFF \
    --column-statistics=0 \
    --result-file result.sql \
    --lock-tables=False \
    --skip-add-locks \
    --skip-quote-names \
    --net-buffer-length=32k \
    employees departments;
