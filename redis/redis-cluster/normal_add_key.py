#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import time
import redis
import string


prefix = str(time.time())
r = redis.Redis(host="localhost", port=6379)

for i in string.ascii_letters:
    r.set(prefix + i, i)

for i in range(10000):
    r.set(prefix + str(i), i)
