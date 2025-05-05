#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import time
import redis
import string


# prefix = str(time.time())
r = redis.RedisCluster(host="localhost", port=7000)

for i in string.ascii_letters:
    r.set(i, i)

for i in range(10000):
    # r.set(prefix + str(i), i)
    r.set(str(i), i)
