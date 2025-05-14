#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import time

from redis import Redis


REDIS = Redis(decode_responses=True)



def test_int():
    start = time.time()
    key = "sorted_set_int"
    REDIS.delete(key)

    for i in range(10000):
        REDIS.zadd(key, {str(i): int(time.time()) - 17_0000_0000})

    for i in range(10000):
        REDIS.zpopmax(key)

    end = time.time()
    print("直接用int耗时: %f", end - start)


def test_float():
    start = time.time()
    key = "sorted_set_float"
    REDIS.delete(key)

    for i in range(10000):
        REDIS.zadd(key, {str(i): time.time()})

    for i in range(10000):
        REDIS.zpopmax(key)

    end = time.time()
    print("直接用float耗时: %f", end - start)


def main():
    test_int()
    test_float()


if __name__ == "__main__":
    main()
