#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2019-08-30 15:46:00

import datetime
import pika
import sys


def run1():
    message = " ".join(sys.argv[1:]) or "Hello World!"
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue="hello")
    channel.basic_publish(exchange="", routing_key="hello", body=message)
    connection.close()

def run3():
    message = " ".join(sys.argv[1:]) or "Hello World!"
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue="task_queue", durable=True)
    channel.basic_publish(exchange="", routing_key="task_queue", body=message)
    connection.close()


if __name__ == "__main__":
    run3()
