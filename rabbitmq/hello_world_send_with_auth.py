#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2018-06-15 14:47:56

#!/usr/bin/env python
import pika

credentials = pika.PlainCredentials('guest', 'password')
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='localhost',
        credentials=credentials,
        ))
channel = connection.channel()


channel.queue_declare(queue='hello')

channel.basic_publish(exchange='',
                      routing_key='hello',
                      body='Hello World!')
print(" [x] Sent 'Hello World!'")
connection.close()
