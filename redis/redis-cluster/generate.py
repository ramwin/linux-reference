#!/usr/bin/env python3
# -*- coding: utf-8 -*-


from pathlib import Path

import jinja2


template = jinja2.Template(Path("redis.conf").read_text())
for port in range(7000, 7009):
    Path(f"cluster-test/{port}").mkdir(exist_ok=True)
    with open(Path(f"cluster-test/{port}/redis.conf"), "w") as f:
        f.write(template.render({
            "port": port,
            "timeout": 2,
        }))
