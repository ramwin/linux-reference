#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2021-02-03 16:04:43


import time
import pika

credentials = pika.PlainCredentials('write', 'write')
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        credentials=credentials, virtual_host="permission"
    ),
)

channel = connection.channel()
channel.queue_declare(queue="queue")
channel.basic_publish(exchange="", routing_key="queue", body=str(time.time()))
