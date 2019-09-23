#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2019-08-30 15:46:00

import pika
import datetime

connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
channel = connection.channel()
channel.queue_declare(queue="hello")
channel.basic_publish(exchange="", routing_key="hello", body="Hello World!")
print("send 'Hello World!' @ {}".format(datetime.datetime.now().strftime("%F %X")))
connection.close()
