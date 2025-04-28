#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import redis
import string


r = redis.RedisCluster(host="localhost", port=7000)

for i in string.ascii_letters:
    r.set(i, i)
