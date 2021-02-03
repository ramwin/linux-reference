#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 08:57:35


import time
from celery import Celery


app = Celery('tasks')
app.config_from_object('tasks_config')


class A():
    def __init__(self):
        self.name = "原来的名字"


@app.task
def hello(a, delay):
    print("开始运行")
    time.sleep(delay)
    a.name = "新名字"
    print("运行完毕: {}".format(x))
    return a


if __name__=='__main__':
    a = A()
    print(hello.delay(a, 2).get())
