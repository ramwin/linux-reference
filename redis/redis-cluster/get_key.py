#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import redis
import string


r = redis.RedisCluster(host="localhost", port=7001, decode_responses=True)

print("".join([
    r.get(i) or "无"
    for i in string.ascii_letters
]))
