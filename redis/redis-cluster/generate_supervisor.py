#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import jinjia2


template = Template(
    "[program:redis_cluster_{{port}}]\n"
    "command=sh run_server.sh\n"
    "directory=/home/wangx/github/linux-reference\n"
    "stdout_logfile_maxbytes=4MB\n"
    "stdout_logfile_backups=20\n"
    "stderr_logfile_maxbytes=4MB\n"
    "stderr_logfile_backups=20\n"
    "autostart=true\n"
    "autorestart=true\n"
    "startretries=3\n"
    "startsecs=20\n"
    "redirect_stderr=false\n"
    "user=wangx\n"
    "environment=PATH="/home/wangx/venv/bin/:/home/wangx/.local/bin:/home/wangx/node/bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin\n"
    "stdout_logfile=/home/wangx/github/linux-reference/stdout.log\n"
    "stderr_logfile=/home/wangx/github/linux-reference/stderr.log\n"
)
