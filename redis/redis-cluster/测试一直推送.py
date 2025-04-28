#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import time

import redis


cluster = redis.RedisCluster(host='localhost', port=7002)

def test():
    """
    测试我一直用7002推送, 关闭7002时能否继续运行
    会的,看来并且迁移slot的时候全程无感
    """
    cnt = 0
    while True:
        cnt += 1
        cluster.rpush('list', time.time())
        time.sleep(0.1)
        if cnt % 20 == 0:
            print(cnt)


test()
