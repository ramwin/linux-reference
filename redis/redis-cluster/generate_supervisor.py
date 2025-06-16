#!/usr/bin/env python3
# -*- coding: utf-8 -*-


from pathlib import Path
from jinja2 import Template


HOME = Path.home()

DIRECTORY=f"{HOME}/github/linux-reference/redis/redis-cluster/cluster-test"

template = Template(
    "[program:redis_cluster_{{port}}]\n"
    "command=redis-server redis.conf\n"
    "directory={{DIRECTORY}}/{{port}}\n"
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
    f'environment=PATH="/opt/homebrew/bin:{HOME}/venv/bin/:{HOME}/.local/bin:{HOME}/node/bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"\n'
    "stdout_logfile={{DIRECTORY}}/stdout.log\n"
    "stderr_logfile={{DIRECTORY}}/stderr.log\n\n\n"
)

with open(Path("supervisor_redis_cluster.ini"), "w") as f:
    for port in range(7000, 7009):
        f.write(template.render({"port": port, "DIRECTORY": DIRECTORY}))

