#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2018-11-12 11:23:41

from celery import Celery
import time
import random


app = Celery('tasks', backend="amqp://rabbit:wangx@localhost//")
ran = random.random()


@app.task
def add(x, y):
    print("当前random: {}".format(ran))
    print("收到任务啦: {x} + {y}".format(x=x, y=y))
    time.sleep(3)
    return x + y
