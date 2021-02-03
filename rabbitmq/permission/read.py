#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2021-02-03 16:10:38


import time
import pika

def callback(ch, method, properties, body):
    print("开始回调")
    print(body)

credentials = pika.PlainCredentials('read', 'read')
credentials = pika.PlainCredentials('write', 'write')  # 这样就不行哟
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        credentials=credentials, virtual_host="permission"
    ),
)

channel = connection.channel()
channel.queue_declare(queue="queue")
channel.basic_consume(queue='queue', auto_ack=True, on_message_callback=callback)
channel.start_consuming()
