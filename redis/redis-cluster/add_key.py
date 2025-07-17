#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import logging
import time
import redis
import string


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")


def main():
    logging.info("开始")
    r = redis.RedisCluster(host="localhost", port=7003)
    while True:
        # prefix = str(time.time())

        for i in string.ascii_letters:
            r.set(i, i)

        for i in range(1000):
            # r.set(prefix + str(i), i)
            r.set(str(i), i)
            time.sleep(0.0001)
        logging.info("又一次写入了1026个key")


if __name__ == "__main__":
    main()
