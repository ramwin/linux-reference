#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang <ramwin@qq.com>


import logging

from celery import Celery


app = Celery("tasks")
app.config_from_object("tasks_config")
logging.basicConfig(level=logging.INFO, filename="info.log", filemode="a")
logging.info("启动服务")


@app.task
def not_zero(x):
    logging.info("处理 %s", x)
    print(type(x))
    print(x)
    if x == 0:
        raise ValueError("x不能为0")
    return x + 1
