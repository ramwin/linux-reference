#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# Xiang Wang @ 2020-03-23 11:17:07


broker_url='redis://localhost'
result_backend='redis://localhost'
timezone = 'Asia/Shanghai'
worker_concurrency=1
worker_redirect_stdouts_level="DEBUG"
worker_prefetch_multiplier=1
enable_utc = False
task_default_queue="tasks"
broker_connection_retry_on_startup=True
worker_redirect_stdouts=True
