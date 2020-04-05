#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 08:57:35


import time
from celery import Celery


app = Celery('tasks')
app.config_from_object('tasks_config')


@app.task
def hello(x=2):
    print("运行Hello")
    time.sleep(x)
    print("hello运行完毕: {}".format(x))
    return 'hello world'


@app.task
def hello2(x=2):
    print("运行hello2")
    print("先调用hello的两个异步")
    hello.delay(x-1)
    hello.delay(x+1)
    print("然后执行hello2")
    time.sleep(x)
    print("执行hello2完毕")


if __name__=='__main__':
    # hello.delay(5)
    hello2.delay(5)
