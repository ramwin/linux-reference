#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 08:57:35


from celery import Celery


app = Celery('hello', broker='amqp://guest@localhost//')


@app.task
def hello():
    return 'hello world'
