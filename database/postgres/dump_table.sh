#!/bin/bash
# Xiang Wang(ramwin@qq.com)

pg_dump \
    --host localhost \
    --no-owner \
    --no-acl \
    --exclude-schema=\
    --rows-per-insert=32 \
    --file=school_student.sql \
    --table school_student \
    --dbname schoolproject
    --where='id BETWEEN 1 AND 1000000'

# 
#    --no-owner 不要所属
#    --no-acl 不要权限
#    --rows-per-insert=1024 每次INSERT只包含1024条记录
#    --schema-only 只导出格式
