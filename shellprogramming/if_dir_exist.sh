#!/bin/bash
# Xiang Wang(ramwin@qq.com)


mkdir -p test_directory

if [ -d test_directory ]
then
    echo "test_directory存在"
fi

rmdir test_directory

if [ -d test_directory ]
then
    echo "test_directory存在"
else
    echo "test_directory不存在"
fi
