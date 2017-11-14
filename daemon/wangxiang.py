#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ 2017-03-23 20:29:15


import time


def main():
    while True:
        file = open('/tmp/output','a')
        file.write(str(time.time()))
        file.write('\n')
        file.close()
        time.sleep(1)


if __name__ == '__main__':
    main()
