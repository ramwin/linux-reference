#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang <ramwin@qq.com>


import logging
from redis import Redis


logging.basicConfig(level=logging.INFO)
REDIS = Redis(decode_responses=True)


def main():
    REDIS.delete("ss")
    REDIS.zadd("ss", {"b": 3})
    badded, aadded, first = REDIS.pipeline()\
        .zadd("ss", {"b": -1})\
        .zadd("ss", {"a": 1})\
        .zrange("ss", 0, 0, withscores=True)\
        .execute()
    logging.info("badded: %s, added: %s, first: %s", badded, aadded, first)


main()
