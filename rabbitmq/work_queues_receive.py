#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2019-08-30 15:59:44


import pika
import datetime
import time

connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
channel = connection.channel()
channel.queue_declare(queue="hello")  # 万一send.py后启动,这样就没有hello这个channel了. 所以安全起见还是先创建一个queue再说

# 这种崩溃了就会丢失任务
def run1():
    def callback(ch, method, properties, body):
        print(" [x] Received %r" % body)
        time.sleep(body.count(b"."))
        print(" [x] Done")


    channel.basic_consume(queue="hello", auto_ack=True, on_message_callback=callback)
    print(" [*] Waiting for messages. To exit press CTRL+C")
    channel.start_consuming()

def run2():
    def callback(ch, method, properties, body):
        print(" [x] Received %r" % body)
        time.sleep(body.count(b"."))
        print(" [x] Done")
        ch.basic_ack(delivery_tag = method.delivery_tag)


    channel.basic_consume(queue="hello", on_message_callback=callback)
    print(" [*] Waiting for messages. To exit press CTRL+C")
    channel.start_consuming()

def run3():
    def callback(ch, method, properties, body):
        print(" [x] Received %r" % body)
        time.sleep(body.count(b"."))
        print(" [x] Done")
        ch.basic_ack(delivery_tag = method.delivery_tag)


    channel.basic_consume(queue="task_queue", on_message_callback=callback)
    print(" [*] Waiting for messages. To exit press CTRL+C")
    channel.start_consuming()

def run4():
    def callback(ch, method, properties, body):
        print(" [x] Received %r" % body)
        time.sleep(body.count(b"."))
        print(" [x] Done")
        ch.basic_ack(delivery_tag = method.delivery_tag)


    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue="task_queue", on_message_callback=callback)
    print(" [*] Waiting for messages. To exit press CTRL+C")
    channel.start_consuming()


if __name__ == "__main__":
    run4()
