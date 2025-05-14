#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import subprocess
import os
from pathlib import Path


def main() -> None:
    for i in range(7000, 7009):
        os.chdir(Path(__file__).parent.joinpath(str(i)))
        subprocess.Popen(["redis-server", "redis.conf"])


if __name__ == "__main__":
    main()
