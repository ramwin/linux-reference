#!/bin/bash
# Xiang Wang(ramwin@qq.com)

pre_step()
{
    echo "运行前"
    pwd
    cd ../
}

run()
{
    echo "run"
    pwd
}

post_step()
{
    echo "运行后"
    pwd
}

pre_step
run
post_step
