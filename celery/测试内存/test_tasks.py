#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2018-11-12 11:29:27

from multiprocessing import Pool
from tasks import add
import time


start = time.time()


def f(arr):
    x, y = arr
    return add.delay(x, y).get()

with Pool(6) as p:
    result = p.map(
        f,
        [
            (1, 2),
            (2, 3),
            (4, 5),
            (5, 6),  # 3.22秒
            (6, 7),  # 6.12秒
            # (7, 8),  # 6.13秒
        ])

end = time.time()
print(result)
print("耗时: {}".format(end-start))
