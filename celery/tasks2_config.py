#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 11:52:40


broker_url='amqp://guest@localhost//'
result_backend='redis://localhost'
timezone = 'Asia/Shanghai'
worker_concurrency=1
worker_redirect_stdouts_level="INFO"
worker_prefetch_multiplier=1
enable_utc = True
task_default_queue="tasks2"
