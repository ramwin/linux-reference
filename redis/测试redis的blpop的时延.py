#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import click
import time

from redis import Redis


REDIS = Redis(decode_responses=True)


def start_send():
    REDIS.delete("test_latency")
    for i in range(10000):
        time.sleep(0.0001)
        REDIS.rpush("test_latency", int(time.time() * 1000000))
    print("发送完毕")


def start_receive():
    delay = 0
    for i in range(10000):
        _, res = REDIS.blpop("test_latency", timeout=100)
        current = int(time.time() * 1000000)
        value = current - int(res)
        delay += value
    print("时延(us):", delay / 10000)


@click.command()
@click.option("--send", is_flag=True)
@click.option("--receive", is_flag=True)
def main(send: bool, receive: bool):
    if send == receive:
        raise ValueError
    if send:
        start_send()
    else:
        start_receive()


if __name__ == "__main__":
    main()
