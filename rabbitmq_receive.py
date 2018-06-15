#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2018-06-15 14:51:54


import pika

credentials = pika.PlainCredentials('guest', 'password')
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='localhost',
        credentials=credentials,
        ))
channel = connection.channel()


channel.queue_declare(queue='hello')

def callback(ch, method, properties, body):
    print(" [x] Received %r" % body)

channel.basic_consume(callback,
                      queue='hello',
                      no_ack=True)

print(' [*] Waiting for messages. To exit press CTRL+C')
channel.start_consuming()
