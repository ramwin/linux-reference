#!/bin/bash


# reshard清理到0以后, 会自动变成slave
redis-cli
    --cluster reshard localhost:7000 \
    --cluster-from <node-id> \
    --cluster-to <node-id> \
    --cluster-slots <number of slots> \
    --cluster-yes
