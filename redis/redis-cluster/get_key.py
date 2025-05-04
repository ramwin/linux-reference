#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import redis
import string

from redis.cluster import ClusterNode, RedisCluster


r = redis.RedisCluster(startup_nodes=[
    ClusterNode('localhost', 7001),
    ClusterNode('localhost', 7002),
    ], decode_responses=True)

print("".join([
    r.get(i) or "无"
    for i in string.ascii_letters
]))
