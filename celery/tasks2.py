#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 08:57:35


import time
from celery import Celery


app = Celery('tasks2')
app.config_from_object('tasks2_config')

@app.task
def hello2(x=2):
    time.sleep(x)
    print("运行tasks2完毕: {}".format(x))
    return 'hello world'


if __name__ == '__main__':
    hello2.delay(5)
