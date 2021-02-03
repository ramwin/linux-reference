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
    print("运行完毕: {}".format(x))
    return 'hello world'

@app.task
def hello2(x=2):
    print("运行Hello")
    time.sleep(x)
    print("运行完毕: {}".format(x))
    return 'hello world2'

if __name__=='__main__':
    hello2.apply_async([2], countdown=10)
