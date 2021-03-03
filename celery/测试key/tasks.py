#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 08:57:35


import logging
import time
from celery import Celery
import redis
logging.basicConfig(
)
log = logging.getLogger()
log.addHandler(
            logging.StreamHandler()
        )


app = Celery('customer-tasks')
app.config_from_object('tasks_config')
routing_key = "customer-task-keys"
delivery_info={"routing_key": routing_key}


@app.task(
        name="self-named-task",
        delivery_info={"routing_key": "customer-task-keys"},
        routing_key="customer-task-keys")
def hello(x=2):
    logging.info("运行Hello")
    time.sleep(x)
    logging.info("运行完毕: {}".format(x))
    return 'hello world'

if __name__=='__main__':
    hello.apply_async([2], countdown=0, delivery_info=delivery_info)
    hello.apply_async([2], countdown=3600*24*365, routing_key=routing_key)
