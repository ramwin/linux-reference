#!/bin/bash
# Xiang Wang(ramwin@qq.com)


redis-cli --cluster check localhost:7000

redis-cli --cluster check localhost:7005
